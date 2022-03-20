//
//  RunLoop.swift
//  
//
//  Created by Van Simmons on 2/17/22.
//
public class AsyncReducer<Action, State> {
    public enum Error: Swift.Error, CaseIterable, Equatable {
        case cancelled
        case alreadyCancelled
        case alreadyTerminated
        case dropped
        case noResult
    }

    public let service: Service<Action>
    public let task: Task<State, Swift.Error>

    public init(
        buffering: AsyncStream<Action>.Continuation.BufferingPolicy = .unbounded,
        initialState: State? = .none,
        initialAction: Action? = .none,
        onStartup: UnsafeContinuation<Void, Never>? = .none,
        onCancel: @Sendable @escaping () -> Void = { },
        onTermination: (@Sendable (AsyncStream<Action>.Continuation.Termination) -> Void)? = .none,
        onFailure: (@Sendable (Swift.Error) -> Void)? = .none,
        onExit: (@Sendable (Action, State) -> Void)? = .none,
        operation: @escaping (State?, Action) async throws -> State,
        exit: @escaping (Action, State) async -> Bool = {_, _ in false }
    ) {
        let localService = Service<Action>(buffering: buffering, onTermination: onTermination)
        self.task = .init { try await withTaskCancellationHandler(handler: onCancel) {
            var isFinished = false
            var state = initialState
            if let initialAction = initialAction { state = try await operation(initialState, initialAction) }
            onStartup?.resume()
            for await action in localService {
                guard !Task.isCancelled else { throw Error.cancelled }
                guard !isFinished else { continue }
                do {
                    let nextState = try await operation(state, action)
                    if await exit(action, nextState) {
                        localService.finish()
                        onExit?(action, nextState)
                        isFinished = true
                    }
                    state = nextState
                }
                catch {
                    onFailure?(error)
                    throw error
                }
            }
            guard !Task.isCancelled else { throw Error.cancelled }
            guard let finalResult = state else { throw Error.noResult }
            return finalResult
        } }
        self.service = localService
    }

    deinit {
        if !task.isCancelled { task.cancel() }
    }

    @inlinable
    public var isCancelled: Bool {
        task.isCancelled
    }

    @inlinable
    public func cancel() -> Void {
        task.cancel()
    }

    @inlinable
    public func finish() -> Void {
        service.finish()
    }

    @inlinable
    public func yield(_ element: Action) -> AsyncStream<Action>.Continuation.YieldResult {
        service.yield(element)
    }

    @inlinable
    public func value() async throws -> State {
        try await task.value
    }
}
