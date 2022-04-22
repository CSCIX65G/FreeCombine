//
//  StatefulChannel.swift
//  
//
//  Created by Van Simmons on 2/17/22.
//

public final class StatefulChannel<State, Action: Sendable> {
    // Optional onStartup can be used from synchronous context
    public struct EventHandler {
        let buffering: AsyncStream<Action>.Continuation.BufferingPolicy
        let onStartup: UnsafeContinuation<Void, Never>?
        let onCancel: @Sendable () -> Void
        let onTermination: @Sendable (AsyncStream<Action>.Continuation.Termination) -> Void
        let onFailure: @Sendable (Swift.Error) -> Void
        let onExit: @Sendable (State) -> Void

        public init(
            buffering: AsyncStream<Action>.Continuation.BufferingPolicy = .bufferingOldest(1),
            onStartup: UnsafeContinuation<Void, Never>? = .none,
            onCancel: @Sendable @escaping () -> Void = { },
            onTermination: @Sendable @escaping (AsyncStream<Action>.Continuation.Termination) -> Void = { _ in },
            onFailure: @Sendable @escaping (Swift.Error) -> Void = { _ in },
            onExit: @Sendable @escaping (State) -> Void = { _ in }
        ) {
            self.buffering = buffering
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
        case internalError
        case alreadyCancelled
        case alreadyTerminated
    }

    public let service: Service<Action>
    public let task: Task<State, Swift.Error>

    public init(service: Service<Action>, task: Task<State, Swift.Error>) {
        self.service = service
        self.task = task
    }

    public convenience init(
        initialState: State,
        eventHandler: EventHandler,
        operation: @escaping (inout State, Action) async throws -> Void
    ) {
        let localService = Service<Action>(
            buffering: eventHandler.buffering,
            onTermination: eventHandler.onTermination
        )
        let localTask = Task<State, Swift.Error> {
            var state = initialState
            let cancellation: @Sendable () -> Void = { localService.finish(); eventHandler.onCancel() }
            return try await withTaskCancellationHandler(handler: cancellation) {
                eventHandler.onStartup?.resume()
                for await action in localService {
                    guard !Task.isCancelled else { continue }
                    do { try await operation(&state, action) }
                    catch {
                        eventHandler.onFailure(error);
                        localService.finish();
                        for await _ in localService { continue; }
                        throw error
                    }
                }
                guard !Task.isCancelled else { throw Error.cancelled }
                eventHandler.onExit(state)
                return state
            }
        }
        self.init(service: localService, task: localTask)
    }

    deinit { task.cancel() }

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

extension StatefulChannel.EventHandler where State == Void {
    public init(
        buffering: AsyncStream<Action>.Continuation.BufferingPolicy = .unbounded,
        onStartup: UnsafeContinuation<Void, Never>? = .none,
        onCancel: @Sendable @escaping () -> Void = { },
        onTermination: @Sendable @escaping (AsyncStream<Action>.Continuation.Termination) -> Void = { _ in },
        onFailure: @Sendable @escaping (Swift.Error) -> Void = { _ in },
        onExit: @Sendable @escaping () -> Void = { }
    ) {
        self.buffering = buffering
        self.onStartup = onStartup
        self.onCancel = onCancel
        self.onTermination = onTermination
        self.onFailure = onFailure
        self.onExit = { _ in onExit() }
    }
}

public extension StatefulChannel where State == Void {
    convenience init(
        eventHandler: EventHandler,
        operation: @escaping (Action) async throws -> Void
    ) {
        self.init(
            initialState: (),
            eventHandler: eventHandler,
            operation: { _, action in try await operation(action) }
        )
    }
}

public protocol SynchronousAction {
    associatedtype State
    var continuation: UnsafeContinuation<State, Swift.Error> { get }
}

public extension StatefulChannel where State: Sendable, Action: SynchronousAction, State == Action.State {
    convenience init(
        initialState: State,
        eventHandler: EventHandler,
        operation: @escaping (inout State, Action) async throws -> Void
    ) {
        let localService = Service<Action>(
            buffering: eventHandler.buffering,
            onTermination: eventHandler.onTermination
        )
        let localTask: Task<State, Swift.Error> = .init {
            var state = initialState
            let cancellation: @Sendable () -> Void = { localService.finish(); eventHandler.onCancel() }
            return try await withTaskCancellationHandler(handler: cancellation) {
                eventHandler.onStartup?.resume()
                for await action in localService {
                    guard !Task.isCancelled else {
                        action.continuation.resume(throwing: Error.cancelled)
                        continue
                    }
                    do { try await operation(&state, action) }
                    catch {
                        eventHandler.onFailure(error);
                        action.continuation.resume(throwing: error)
                        localService.finish()
                        for await action in localService {
                            action.continuation.resume(throwing: Error.internalError)
                        }
                        throw error
                    }
                    action.continuation.resume(returning: state)
                }
                guard !Task.isCancelled else { throw Error.cancelled }
                eventHandler.onExit(state)
                return state
            }
        }

        self.init(service: localService, task: localTask)
    }
}
