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
struct FoldState<Input: Sendable, Output: Sendable> {
    enum Action {
        case fold(Result<(Int, Input), Swift.Error>, Resumption<Void>)
        case removeCancellable(Int, Resumption<Void>)
        var resumption: Resumption<Void> {
            switch self {
                case .fold(_, let resumption): return resumption
                case .removeCancellable(_, let resumption): return resumption
            }
        }
    }

    let fold: (inout Result<Output, Swift.Error>, Result<(Int, Input), Swift.Error>) async -> Reducer<Self, Action>.Effect
    let downstream: (Result<Output, Swift.Error>) async -> Void

    var currentValue: Result<Output, Swift.Error>
    var cancellables: [Int: Cancellable<Void>]

    init<S: Sequence>(
        initialValue: Result<Output, Swift.Error>,
        channel: Channel<FoldState<Input, Output>.Action>,
        fold: @escaping (inout Result<Output, Swift.Error>, Result<(Int, Input), Swift.Error>) async -> Reducer<Self, Action>.Effect,
        downstream: @escaping (Result<Output, Swift.Error>) async -> Void,
        futures: S
    ) async where S.Element == Future<Input> {
        self.currentValue = initialValue
        self.fold = fold
        self.downstream = downstream
        var localCancellables = [Int: Cancellable<Void>]()
        let upstreams = futures.enumerated()
            .map { index, future in future.map { value in (index, value) } }

        for (index, future) in upstreams.enumerated() {
            localCancellables[index] = await channel.consume(future: future, using: { result, resumption in
                .fold(result, resumption)
            })
        }
        cancellables = localCancellables
    }

    static func create<S: Sequence>(
        initialValue: Result<Output, Swift.Error>,
        fold: @escaping (inout Result<Output, Swift.Error>, Result<(Int, Input), Swift.Error>) async -> Reducer<Self, Action>.Effect,
        futures: S
    ) -> (@escaping (Result<Output, Swift.Error>) async -> Void) -> (Channel<FoldState<Input, Output>.Action>) async -> Self
    where S.Element == Future<Input> {
        { downstream in { channel in
            await .init(
                initialValue: initialValue,
                channel: channel,
                fold: fold,
                downstream: downstream,
                futures: futures
            )
        } }
    }

    static func complete(state: inout Self, completion: Reducer<Self, Self.Action>.Completion) async -> Void {
        for can in state.cancellables.values { can.cancel(); _ = await can.result }
        await state.downstream(state.currentValue)
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
            case let .fold(newValue, resumption):
                return await fold(&currentValue, newValue)
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
                            await downstream(currentValue)
                        default:
                            ()  // Can't happen in Futureland
                    }
                    return .completion(.exit)
                }
                return .none
        }
    }
}
