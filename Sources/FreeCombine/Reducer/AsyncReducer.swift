//
//  RunLoop.swift
//  
//
//  Created by Van Simmons on 2/17/22.
//
public class AsyncReducer<State, Action> {
    public enum Error: Swift.Error, CaseIterable, Equatable {
        case cancelled
        case dropped
        case alreadyCancelled
        case alreadyTerminated
    }

    public let service: Service<Action>
    public let task: Task<State, Swift.Error>

    public init(
        buffering: AsyncStream<Action>.Continuation.BufferingPolicy = .unbounded,
        initialState: State,
        onStartup: UnsafeContinuation<Void, Never>? = .none,
        onCancel: @Sendable @escaping () -> Void = { },
        onTermination: (@Sendable (AsyncStream<Action>.Continuation.Termination) -> Void)? = .none,
        onFailure: (@Sendable (Swift.Error) -> Void)? = .none,
        onExit: (@Sendable (State) -> Void)? = .none,
        operation: @escaping (inout State, Action, Service<Action>) async throws -> Void
    ) {
        let localService = Service<Action>(buffering: buffering, onTermination: onTermination)
        self.task = .init { try await withTaskCancellationHandler(handler: onCancel) {
            var state = initialState
            onStartup?.resume()
            for await action in localService {
                guard !Task.isCancelled else { throw Error.cancelled }
                do {
                    try await operation(&state, action, localService)
                }
                catch {
                    onFailure?(error); throw error
                }
            }
            guard !Task.isCancelled else { throw Error.cancelled }
            onExit?(state)
            return state
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
