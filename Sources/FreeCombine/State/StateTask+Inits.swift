//
//  StateTask+Inits.swift
//  
//
//  Created by Van Simmons on 5/15/22.
//

public extension StateTask {
    static func stateTask(
        initialState: @escaping (Channel<Action>) async -> State,
        buffering: AsyncStream<Action>.Continuation.BufferingPolicy = .bufferingOldest(1),
        onCancel: @escaping () -> Void = { },
        onCompletion: @escaping (State, Completion) -> Void = { _, _ in },
        reducer: @escaping (inout State, Action) async throws -> Void
    ) async -> Self {
        var stateTask: Self!
        await withUnsafeContinuation { stateTaskContinuation in
            stateTask = Self.init(
                initialState: initialState,
                buffering: buffering,
                onStartup: stateTaskContinuation,
                onCancel: onCancel,
                onCompletion: onCompletion,
                reducer: reducer
            )
        }
        return stateTask
    }

    convenience init(
        initialState: State,
        buffering: AsyncStream<Action>.Continuation.BufferingPolicy = .bufferingOldest(1),
        onStartup: UnsafeContinuation<Void, Never>? = .none,
        onCancel: @escaping () -> Void = { },
        onCompletion: @escaping (State, Completion) -> Void = { _, _ in },
        reducer: @escaping (inout State, Action) async throws -> Void
    ) {
        self.init(
            initialState: {_ in initialState},
            buffering: buffering,
            onStartup: onStartup,
            onCancel: onCancel,
            onCompletion: onCompletion,
            reducer: reducer
        )
    }
}
