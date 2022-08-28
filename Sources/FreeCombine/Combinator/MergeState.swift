//
//  MergeState.swift
//  
//
//  Created by Van Simmons on 5/19/22.
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
struct MergeState<Output: Sendable> {
    enum Action {
        case setValue(AsyncStream<(Int, Output)>.Result, Resumption<Demand>)
        case removeCancellable(Int, Resumption<Demand>)
        case failure(Int, Error, Resumption<Demand>)
        var resumption: Resumption<Demand> {
            switch self {
                case .setValue(_, let resumption): return resumption
                case .removeCancellable(_, let resumption): return resumption
                case .failure(_, _, let resumption): return resumption
            }
        }
    }

    let downstream: (AsyncStream<Output>.Result) async throws -> Demand

    var cancellables: [Int: Cancellable<Demand>]
    var mostRecentDemand: Demand = .more

    init<S: Sequence>(
        channel: Channel<MergeState<Output>.Action>,
        downstream: @escaping (AsyncStream<(Output)>.Result) async throws -> Demand,
        upstreams upstream1: Publisher<Output>,
        _ upstream2: Publisher<Output>,
        _ otherUpstreams: S
    ) async where S.Element == Publisher<Output> {
        self.downstream = downstream
        var localCancellables = [Int: Cancellable<Demand>]()
        let upstreams = ([upstream1, upstream2] + otherUpstreams).enumerated()
            .map { index, publisher in publisher.map { value in (index, value) } }

        for (index, publisher) in upstreams.enumerated() {
            localCancellables[index] = await channel.consume(publisher: publisher, using: { result, continuation in
                switch result {
                    case .value:
                        return .setValue(result, continuation)
                    case .completion(.finished), .completion(.cancelled):
                        return .removeCancellable(index, continuation)
                    case let .completion(.failure(error)):
                        return .failure(index, error, continuation)
                }
            })
        }
        cancellables = localCancellables
    }

    static func create<S: Sequence>(
        upstreams upstream1: Publisher<Output>,
        _ upstream2: Publisher<Output>,
        _ otherUpstreams: S
    ) -> (@escaping (AsyncStream<Output>.Result) async throws -> Demand) -> (Channel<MergeState<Output>.Action>) async -> Self
    where S.Element == Publisher<Output> {
        { downstream in { channel in
            await .init(channel: channel, downstream: downstream, upstreams: upstream1, upstream2, otherUpstreams)
        } }
    }

    static func complete(state: inout Self, completion: Reducer<Self, Self.Action>.Completion) async -> Void {
        for can in state.cancellables.values { can.cancel(); _ = await can.result }
        state.cancellables.removeAll()
        guard state.mostRecentDemand != .done else { return }
        do {
            switch completion {
                case .finished:
                    state.mostRecentDemand = try await state.downstream(.completion(.finished))
                case .cancel:
                    state.mostRecentDemand = try await state.downstream(.completion(.cancelled))
                case .exit, .failure:
                    () // These came from downstream and should not go down again
            }
        } catch { }
    }

    static func dispose(action: Self.Action, completion: Reducer<Self, Self.Action>.Completion) async -> Void {
        action.resumption.resume(throwing: PublisherError.cancelled)
    }

    static func reduce(
        `self`: inout Self,
        action: Self.Action
    ) async throws -> Reducer<Self, Action>.Effect {
        return try await `self`.reduce(action: action)
    }

    private mutating func reduce(
        action: Self.Action
    ) async throws -> Reducer<Self, Action>.Effect {
        guard !Task.isCancelled else {
            action.resumption.resume(throwing: PublisherError.cancelled)
            return .completion(.cancel)
        }
        switch action {
            case let .setValue(value, resumption):
                return try await reduceValue(value, resumption)
            case let .removeCancellable(index, resumption):
                resumption.resume(returning: .done)
                if let c = cancellables.removeValue(forKey: index) {
                    let _ = await c.result
                }
                if cancellables.count == 0 {
                    let c: Completion = Task.isCancelled ? .cancelled : .finished
                    mostRecentDemand = try await downstream(.completion(c))
                    return .completion(.exit)
                }
                return .none
            case let .failure(_, error, resumption):
                resumption.resume(returning: .done)
                cancellables.removeAll()
                mostRecentDemand = try await downstream(.completion(.failure(error)))
                return .completion(.failure(error))
        }
    }

    private mutating func reduceValue(
        _ value: AsyncStream<(Int, Output)>.Result,
        _ resumption: Resumption<Demand>
    ) async throws -> Reducer<Self, Action>.Effect {
        switch value {
            case let .value((index, output)):
                guard let _ = cancellables[index] else {
                    fatalError("received value after task completion")
                }
                do {
                    mostRecentDemand = try await downstream(.value(output))
                    resumption.resume(returning: mostRecentDemand)
                    return .none
                }
                catch {
                    resumption.resume(throwing: error)
                    return .completion(.failure(error))
                }
            case let .completion(.failure(error)):
                resumption.resume(returning: .done)
                return .completion(.failure(error))
            case .completion(.finished):
                resumption.resume(returning: .done)
                return .none
            case .completion(.cancelled):
                resumption.resume(returning: .done)
                return .none
        }
    }
}
