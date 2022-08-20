//
//  CombineLatestState.swift
//  
//
//  Created by Van Simmons on 6/4/22.
//
//  Copyright 2022, ComputeCycles, LLC
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//
struct CombineLatestState<Left: Sendable, Right: Sendable> {
    typealias CombinatorAction = Self.Action
    enum Action {
        case setLeft(AsyncStream<Left>.Result, Resumption<Demand>)
        case setRight(AsyncStream<Right>.Result, Resumption<Demand>)
        var resumption: Resumption<Demand> {
            switch self {
                case .setLeft(_, let resumption): return resumption
                case .setRight(_, let resumption): return resumption
            }
        }
    }

    let downstream: (AsyncStream<(Left?, Right?)>.Result) async throws -> Demand
    let leftCancellable: Cancellable<Demand>
    let rightCancellable: Cancellable<Demand>

    var mostRecentDemand: Demand
    var left: (value: Left?, resumption: Resumption<Demand>)? = .none
    var right: (value: Right?, resumption: Resumption<Demand>)? = .none
    var leftComplete = false
    var rightComplete = false

    init(
        channel: Channel<CombineLatestState<Left, Right>.Action>,
        downstream: @escaping (AsyncStream<(Left?, Right?)>.Result) async throws -> Demand,
        mostRecentDemand: Demand = .more,
        left: Publisher<Left>,
        right: Publisher<Right>
    ) async {
        self.downstream = downstream
        self.mostRecentDemand = mostRecentDemand
        self.leftCancellable = await channel.consume(publisher: left, using: CombineLatestState<Left, Right>.Action.setLeft)
        self.rightCancellable = await channel.consume(publisher: right, using: CombineLatestState<Left, Right>.Action.setRight)
    }

    static func create(
        left: Publisher<Left>,
        right: Publisher<Right>
    ) -> (@escaping (AsyncStream<(Left?, Right?)>.Result) async throws -> Demand) -> (Channel<CombineLatestState<Left, Right>.Action>) async -> Self {
        { downstream in { channel in
            await .init(channel: channel, downstream: downstream, left: left, right: right)
        } }
    }

    static func dispose(action: Self.Action, completion: Reducer<Self, Self.Action>.Completion) async -> Void {
        action.resumption.resume(throwing: PublisherError.cancelled)
    }

    static func complete(state: inout Self, completion: Reducer<Self, Self.Action>.Completion) async -> Void {
        state.mostRecentDemand = .done
        if let left = state.left {
            left.resumption.resume(returning: .done)
            state.left = .none
        } else {
            state.leftCancellable.cancel()
        }
        if let right = state.right {
            right.resumption.resume(returning: .done)
            state.right = .none
        } else {
            state.rightCancellable.cancel()
        }
        switch completion {
            case .cancel:
                _ = try? await state.downstream(.completion(.cancelled))
            case .exit, .finished:
                _ = try? await state.downstream(.completion(.finished))
            case let .failure(error):
                _ = try? await state.downstream(.completion(.failure(error)))
        }
    }

    static func reduce(`self`: inout Self, action: Self.Action) async throws -> Reducer<Self, Action>.Effect {
        guard !Task.isCancelled else {
            action.resumption.resume(throwing: PublisherError.cancelled)
            return .completion(.cancel)
        }
        return try await `self`.reduce(action: action)
    }

    private mutating func reduce(
        action: Self.Action
    ) async throws -> Reducer<Self, Action>.Effect {
        switch action {
            case let .setLeft(leftResult, leftContinuation):
                if mostRecentDemand == .done { leftContinuation.resume(returning: .done) }
                else { return try await handleLeft(leftResult, leftContinuation) }
            case let .setRight(rightResult, rightContinuation):
                if mostRecentDemand == .done { rightContinuation.resume(returning: .done) }
                else { return try await handleRight(rightResult, rightContinuation) }
        }
        return .none
    }

    private mutating func handleLeft(
        _ leftResult: AsyncStream<Left>.Result,
        _ leftResumption: Resumption<Demand>
    ) async throws -> Reducer<Self, Action>.Effect {
        switch leftResult {
            case let .value((value)):
                left = (value, leftResumption)
                guard !Task.isCancelled else {
                    leftResumption.resume(returning: .done)
                    return .completion(.cancel)
                }
                mostRecentDemand = try await downstream(.value((value, right?.value)))
                leftResumption.resume(returning: mostRecentDemand)
                return .none
            case .completion(_):
                leftComplete = true
                leftResumption.resume(returning: .done)
                left = .none
                return leftComplete && rightComplete ? .completion(.exit) : .none
        }
    }

    private mutating func handleRight(
        _ rightResult: AsyncStream<Right>.Result,
        _ rightResumption: Resumption<Demand>
    ) async throws -> Reducer<Self, Self.Action>.Effect {
        switch rightResult {
            case let .value((value)):
                right = (value, rightResumption)
                guard !Task.isCancelled else {
                    rightResumption.resume(returning: .done)
                    return .completion(.cancel)
                }
                mostRecentDemand = try await downstream(.value((left?.value, value)))
                rightResumption.resume(returning: mostRecentDemand)
                return .none
            case .completion(_) :
                rightComplete = true
                rightResumption.resume(returning: .done)
                right = .none
                return leftComplete && rightComplete ? .completion(.exit) : .none
        }
    }
}
