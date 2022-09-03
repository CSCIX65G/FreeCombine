//
//  Combinator.swift
//  
//
//  Created by Van Simmons on 9/2/22.
//

public extension Future {
    init<State, Action>(
        initialState: @escaping (@escaping (Result<Output, Swift.Error>) async -> Void) -> (Channel<Action>) async -> State,
        buffering: AsyncStream<Action>.Continuation.BufferingPolicy,
        reducer: Reducer<State, Action>
    ) {
        self = .init { resumption, downstream in
            .init {
                let stateTask = try await Channel(buffering: buffering).stateTask(
                    initialState: initialState(downstream),
                    reducer: reducer
                )

                return try await withTaskCancellationHandler(
                    operation: {
                        resumption.resume()
                        guard !Task.isCancelled else { throw PublisherError.cancelled }
                        _ = await stateTask.result
                        return
                    },
                    onCancel: stateTask.cancel
                )
            }
        }
    }
}
