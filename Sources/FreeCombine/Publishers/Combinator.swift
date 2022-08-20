//
//  Combinator.swift
//  
//
//  Created by Van Simmons on 5/8/22.
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
public func Combinator<Output: Sendable, State, Action>(
    initialState: @escaping (@escaping (AsyncStream<Output>.Result) async throws -> Demand) -> (Channel<Action>) async -> State,
    buffering: AsyncStream<Action>.Continuation.BufferingPolicy,
    reducer: Reducer<State, Action>,
    extractor: @escaping (State) -> Demand
) -> Publisher<Output> {
    .init(
        initialState: initialState,
        buffering: buffering,
        reducer: reducer,
        extractor: extractor
    )
}

public extension Publisher {
    init<State, Action>(
        initialState: @escaping (@escaping (AsyncStream<Output>.Result) async throws -> Demand) -> (Channel<Action>) async -> State,
        buffering: AsyncStream<Action>.Continuation.BufferingPolicy,
        reducer: Reducer<State, Action>,
        extractor: @escaping (State) -> Demand
    ) {
        self = .init { continuation, downstream in
            .init {
                let stateTask = try await Channel(buffering: buffering).stateTask(
                    initialState: initialState(downstream),
                    reducer: reducer
                )

                return try await withTaskCancellationHandler(handler: stateTask.cancel) {
                    continuation.resume()
                    guard !Task.isCancelled else { throw PublisherError.cancelled }
                    let finalState = try await stateTask.value
                    return extractor(finalState)
                }
            }
        }
    }
}
