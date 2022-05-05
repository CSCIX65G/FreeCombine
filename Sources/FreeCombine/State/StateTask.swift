//
//  StateTask.swift
//  
//  Created by Van Simmons on 2/17/22.
//

public final class StateTask<State, Action: Sendable> {
    public enum Completion {
        case termination(State)
        case exit(State)
        case failure(Swift.Error)
        case cancel(State)
    }

    public enum Error: Swift.Error {
        case cancelled
        case internalError
    }

    private let channel: Channel<Action>
    private let task: Task<State, Swift.Error>

    public init(channel: Channel<Action>, task: Task<State, Swift.Error>) {
        self.channel = channel
        self.task = task
    }
    
    public static func stateTask(
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

    public convenience init(
        initialState: @escaping (Channel<Action>) async -> State,
        buffering: AsyncStream<Action>.Continuation.BufferingPolicy = .bufferingOldest(1),
        onStartup: UnsafeContinuation<Void, Never>? = .none,
        onCancel: @escaping () -> Void = { },
        onCompletion: @escaping (State, Completion) -> Void = { _, _ in },
        reducer: @escaping (inout State, Action) async throws -> Void
    ) {
        let localChannel = Channel<Action>(buffering: buffering)
        let localTask = Task<State, Swift.Error> {
            let cancellation: @Sendable () -> Void = { localChannel.finish(); onCancel() }
            return try await withTaskCancellationHandler(handler: cancellation) {
                onStartup?.resume()
                var state = await initialState(localChannel)
                for await action in localChannel {
                    guard !Task.isCancelled else { continue }
                    do { try await reducer(&state, action) }
                    catch {
                        localChannel.finish();
                        for await _ in localChannel { continue; }
                        onCompletion(state, .failure(error));
                        throw error
                    }
                }
                guard !Task.isCancelled else {
                    onCompletion(state, .cancel(state))
                    throw Error.cancelled
                }
                onCompletion(state, .termination(state))
                return state
            }
        }
        self.init(channel: localChannel, task: localTask)
    }

    deinit {
        task.cancel()
    }

    public var isCancelled: Bool {
        task.isCancelled
    }

    public func cancel() -> Void {
        task.cancel()
    }

    public func finish() -> Void {
        channel.finish()
    }

    public func yield(_ element: Action) -> AsyncStream<Action>.Continuation.YieldResult {
        channel.yield(element)
    }

    public var finalState: State {
        get async throws { try await task.value }
    }

    @inlinable
    public var result: Result<State, Swift.Error> {
        get async {
            do {
                let success = try await finalState
                return .success(success)
            } catch {
                return .failure(error)
            }
        }
    }
}

public extension StateTask where State == Void {
    convenience init(
        buffering: AsyncStream<Action>.Continuation.BufferingPolicy = .bufferingOldest(1),
        onStartup: UnsafeContinuation<Void, Never>? = .none,
        onCancel: @escaping () -> Void = { },
        onCompletion: @escaping (State, Completion) -> Void = {_,  _ in },
        reducer: @escaping (Action) async throws -> Void
    ) {
        self.init(
            initialState: {_ in },
            buffering: buffering,
            onStartup: onStartup,
            onCancel: onCancel,
            onCompletion: onCompletion,
            reducer: { _, action in try await reducer(action) }
        )
    }
}
