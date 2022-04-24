//
//  StatefulChannel.swift
//  
//
//  Created by Van Simmons on 2/17/22.
//

public final class StateThread<State, Action: Sendable> {
    public struct EventHandler {
        let onCancel: @Sendable () -> Void
        let onFailure: @Sendable (Swift.Error) -> Void
        let onExit: @Sendable (State) -> Void

        public init(
            onCancel: @Sendable @escaping () -> Void = { },
            onFailure: @Sendable @escaping (Swift.Error) -> Void = { _ in },
            onExit: @Sendable @escaping (State) -> Void = { _ in }
        ) {
            self.onCancel = onCancel
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

    public let channel: Channel<Action>
    public let task: Task<State, Swift.Error>

    public init(channel: Channel<Action>, task: Task<State, Swift.Error>) {
        self.channel = channel
        self.task = task
    }

    public static func stateThread(
        initialState: State,
        buffering: AsyncStream<Action>.Continuation.BufferingPolicy = .bufferingOldest(1),
        eventHandler: EventHandler = .init(),
        operation: @escaping (inout State, Action) async throws -> Void
    ) async -> Self {
        var stateThread: Self!
        await withUnsafeContinuation { stateThreadContinuation in
            stateThread = Self.init(
                initialState: initialState,
                buffering: buffering,
                onStartup: stateThreadContinuation,
                eventHandler: eventHandler,
                operation: operation
            )
        }
        return stateThread
    }
    
    public convenience init(
        initialState: State,
        buffering: AsyncStream<Action>.Continuation.BufferingPolicy = .bufferingOldest(1),
        onStartup: UnsafeContinuation<Void, Never>?,
        eventHandler: EventHandler = .init(),
        operation: @escaping (inout State, Action) async throws -> Void
    ) {
        let localService = Channel<Action>(buffering: buffering)
        let localTask = Task<State, Swift.Error> {
            var state = initialState
            let cancellation: @Sendable () -> Void = { localService.finish(); eventHandler.onCancel() }
            return try await withTaskCancellationHandler(handler: cancellation) {
                onStartup?.resume()
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
        self.init(channel: localService, task: localTask)
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
        channel.finish()
    }

    @inlinable
    public func yield(_ element: Action) -> AsyncStream<Action>.Continuation.YieldResult {
        channel.yield(element)
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

extension StateThread.EventHandler where State == Void {
    public init(
        onCancel: @Sendable @escaping () -> Void = { },
        onFailure: @Sendable @escaping (Swift.Error) -> Void = { _ in },
        onExit: @Sendable @escaping () -> Void = { }
    ) {
        self.onCancel = onCancel
        self.onFailure = onFailure
        self.onExit = { _ in onExit() }
    }
}

public extension StateThread where State == Void {
    convenience init(
        buffering: AsyncStream<Action>.Continuation.BufferingPolicy = .bufferingOldest(1),
        onStartup: UnsafeContinuation<Void, Never>? = .none,
        eventHandler: EventHandler,
        operation: @escaping (Action) async throws -> Void
    ) {
        self.init(
            initialState: (),
            buffering: buffering,
            onStartup: onStartup,
            eventHandler: eventHandler,
            operation: { _, action in try await operation(action) }
        )
    }
}

public protocol SynchronousAction: Sendable {
    associatedtype Sync
    var continuation: UnsafeContinuation<Sync, Swift.Error> { get }
}

public extension StateThread where State: Sendable, Action: SynchronousAction, State == Action.Sync {
    convenience init(
        initialState: State,
        buffering: AsyncStream<Action>.Continuation.BufferingPolicy = .bufferingOldest(1),
        onStartup: UnsafeContinuation<Void, Never>? = .none,
        eventHandler: EventHandler = .init(),
        operation: @escaping (inout State, Action) async throws -> Void
    ) {
        let localService = Channel<Action>(buffering: buffering)
        let localTask: Task<State, Swift.Error> = .init {
            var state = initialState
            let cancellation: @Sendable () -> Void = { localService.finish(); eventHandler.onCancel() }
            return try await withTaskCancellationHandler(handler: cancellation) {
                onStartup?.resume()
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
        self.init(channel: localService, task: localTask)
    }
}

public extension StateThread {
    func consume<Upstream>(
        publisher: Publisher<Upstream>,
        using action: @escaping (AsyncStream<Upstream>.Result, UnsafeContinuation<Demand, Swift.Error>) -> Action
    ) async -> Task<Demand, Swift.Error> {
        await publisher { upstreamValue in
            try await withUnsafeThrowingContinuation { continuation in
                guard case .enqueued = self.yield(action(upstreamValue, continuation)) else {
                    continuation.resume(throwing: Publisher<Upstream>.Error.internalError)
                    return
                }
            }
        }
    }
}