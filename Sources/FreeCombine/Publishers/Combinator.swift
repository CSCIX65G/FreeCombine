//
//  Combinator.swift
//  
//
//  Created by Van Simmons on 5/8/22.
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
                    continuation?.resume()
                    guard !Task.isCancelled else { throw PublisherError.cancelled }
                    let finalState = try await stateTask.value
                    return extractor(finalState)
                }
            }
        }
    }
}
