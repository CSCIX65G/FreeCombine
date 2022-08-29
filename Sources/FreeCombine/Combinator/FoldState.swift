//
//  FoldState.swift
//  
//
//  Created by Van Simmons on 8/28/22.
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
struct FoldState<Output: Sendable> {
    enum Action {
        case fold(Result<(Int, Output), Swift.Error>, Resumption<Void>)
        case removeCancellable(Int, Resumption<Void>)
        case failure(Int, Error, Resumption<Void>)
        var resumption: Resumption<Void> {
            switch self {
                case .fold(_, let resumption): return resumption
                case .removeCancellable(_, let resumption): return resumption
                case .failure(_, _, let resumption): return resumption
            }
        }
    }

    let downstream: (Result<Output, Swift.Error>) async -> Void

    var currentValue: Output
    var cancellables: [Int: Cancellable<Void>]

    init<S: Sequence>(
        initialValue: Output,
        channel: Channel<FoldState<Output>.Action>,
        downstream: @escaping (Result<Output, Swift.Error>) async -> Void,
        upstreams upstream1: Future<Output>,
        _ upstream2: Future<Output>,
        _ otherUpstreams: S
    ) async where S.Element == Future<Output> {
        self.currentValue = initialValue
        self.downstream = downstream
        var localCancellables = [Int: Cancellable<Void>]()
        let upstreams = ([upstream1, upstream2] + otherUpstreams).enumerated()
            .map { index, publisher in publisher.map { value in (index, value) } }

        for (index, future) in upstreams.enumerated() {
            localCancellables[index] = await channel.consume(future: future, using: { result, resumption in
                .fold(result, resumption)
            })
        }
        cancellables = localCancellables
    }

    static func create<S: Sequence>(
        initialValue: Output,
        upstreams upstream1: Future<Output>,
        _ upstream2: Future<Output>,
        _ otherUpstreams: S
    ) -> (@escaping (Result<Output, Swift.Error>) async -> Void) -> (Channel<FoldState<Output>.Action>) async -> Self
    where S.Element == Future<Output> {
        { downstream in { channel in
            await .init(
                initialValue: initialValue,
                channel: channel,
                downstream: downstream,
                upstreams: upstream1, upstream2, otherUpstreams
            )
        } }
    }

    static func complete(state: inout Self, completion: Reducer<Self, Self.Action>.Completion) async -> Void {
        for can in state.cancellables.values { can.cancel(); _ = await can.result }
        state.cancellables.removeAll()
    }

    static func dispose(action: Self.Action, completion: Reducer<Self, Self.Action>.Completion) async -> Void {
        action.resumption.resume(throwing: FutureError.cancelled)
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
            action.resumption.resume(throwing: FutureError.cancelled)
            return .completion(.cancel)
        }
        switch action {
            case let .fold(value, resumption):
                return try await reduceValue(value, resumption)
            case let .removeCancellable(index, resumption):
                resumption.resume()
                if let c = cancellables.removeValue(forKey: index) {
                    let _ = await c.result
                }
                if cancellables.count == 0 {
                    let c: Completion = Task.isCancelled ? .cancelled : .finished
                    switch c {
                        case .cancelled:
                            await downstream(.failure(FutureError.cancelled))
                        case .finished:
                            await downstream(.success(currentValue))
                        default:
                            ()  // Can't happen in Futureland
                    }
                    return .completion(.exit)
                }
                return .none
            case let .failure(_, error, resumption):
                resumption.resume()
                cancellables.removeAll()
                await downstream(.failure(error))
                return .completion(.failure(error))
        }
    }

    private mutating func reduceValue(
        _ value: Result<(Int, Output), Swift.Error>,
        _ resumption: Resumption<Void>
    ) async throws -> Reducer<Self, Action>.Effect {
        switch value {
            case let .success((index, output)):
                guard let _ = cancellables[index] else {
                    fatalError("received value after task completion")
                }
                await downstream(.success(output))
                resumption.resume()
                return .none
            case let .failure(error):
                resumption.resume()
                return .completion(.failure(error))
        }
    }
}
