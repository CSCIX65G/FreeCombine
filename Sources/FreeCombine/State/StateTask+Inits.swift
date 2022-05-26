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
        onCancel: @Sendable @escaping () -> Void = { },
        onCompletion: @escaping (inout State, Reducer<State, Action>.Completion) async -> Void = { _, _ in },
        reducer: Reducer<State, Action>
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
        onCancel: @Sendable @escaping () -> Void = { },
        onCompletion: @escaping (inout State, Reducer<State, Action>.Completion) async -> Void = { _, _ in },
        reducer: Reducer<State, Action>
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

    convenience init(
        initialState: @escaping (Channel<Action>) async -> State,
        buffering: AsyncStream<Action>.Continuation.BufferingPolicy = .bufferingOldest(1),
        onStartup: UnsafeContinuation<Void, Never>? = .none,
        onCancel: @Sendable @escaping () -> Void = { },
        onCompletion: @escaping (inout State, Reducer<State, Action>.Completion) async -> Void = { _, _ in },
        reducer: Reducer<State, Action>
    ) {
        self.init(
            channel: Channel<Action>(buffering: buffering),
            initialState: initialState,
            onStartup: onStartup,
            onCancel: onCancel,
            onCompletion: onCompletion,
            reducer: reducer
        )
    }
}
