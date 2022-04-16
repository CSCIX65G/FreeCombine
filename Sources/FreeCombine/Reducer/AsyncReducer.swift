//
//  RunLoop.swift
//  
//
//  Created by Van Simmons on 2/17/22.
//
public class AsyncReducer<State, Action> {
    public struct EventHandler {
        let onStartup: UnsafeContinuation<Void, Never>?
        let onCancel: @Sendable () -> Void
        let onTermination: @Sendable (AsyncStream<Action>.Continuation.Termination) -> Void
        let onFailure: @Sendable (Swift.Error) -> Void
        let onExit: @Sendable (State) -> Void

        public init(
            onStartup: UnsafeContinuation<Void, Never>? = .none,
            onCancel: @Sendable @escaping () -> Void = { },
            onTermination: @Sendable @escaping (AsyncStream<Action>.Continuation.Termination) -> Void = { _ in },
            onFailure: @Sendable @escaping (Swift.Error) -> Void = { _ in },
            onExit: @Sendable @escaping (State) -> Void = { _ in }
        ) {
            self.onStartup = onStartup
            self.onCancel = onCancel
            self.onTermination = onTermination
            self.onFailure = onFailure
            self.onExit = onExit
        }
    }

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
        eventHandler: EventHandler,
        operation: @escaping (inout State, Action) async throws -> Effect<Action>
    ) {
        let localService = Service<Action>(buffering: buffering, onTermination: eventHandler.onTermination)
        self.service = localService
        self.task = .init { try await withTaskCancellationHandler(handler: eventHandler.onCancel) {
            var cancellables: Set<Task<Demand, Swift.Error>> = []
            var state = initialState
            eventHandler.onStartup?.resume()
            guard !Task.isCancelled else { throw Error.cancelled }
            for await action in localService {
                guard !Task.isCancelled else { break }
                do {
                    let e = try await operation(&state, action)
                    switch e {
                        case .none:
                            ()
                        case .fireAndForget(let f):
                            f()
                        case .published(let p):
                            let _: Void = await withUnsafeContinuation { continuation in
                                cancellables.insert( p.sink(
                                    onStartup: continuation,
                                    receiveValue: { action in localService.yield(action) }
                                ) )
                            }
                    }
                }
                catch { eventHandler.onFailure(error); throw error }
                guard !Task.isCancelled else { break }
            }
            guard !Task.isCancelled else { throw Error.cancelled }
            eventHandler.onExit(state)
            return state
        } }
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
    public var finalState: State {
        get async throws { try await task.value }
    }
}
