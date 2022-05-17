//
//  StateTask.swift
//  
//  Created by Van Simmons on 2/17/22.
//
/*:
 #actor problems

 1. no oneway funcs (can't call from synchronous code)
 2. can't selectively block callers
 3. can't block on internal state (can only block with async call to another task)
 4. no concept of cancellation
 5. execute on global actor queues (generally not needed or desirable)

 #actor solutions: statetasks

 1. LOCK FREE CHANNELS
 2. Haskell translation: ∀s in Rank-N types becomes a Task

 # statetask actions:

 2. sendable funcs
 3. routable
 4. value types
 5. some actions are blocking, these need special handling (think DO oneway keyword)
 */

public final class StateTask<State, Action: Sendable> {
    public enum Completion {
        case termination(State)
        case failure(Swift.Error)
        case cancel(State)
    }

    private let channel: Channel<Action>
    public let task: Task<State, Swift.Error>

    deinit {
        task.cancel()
    }

    public init(channel: Channel<Action>, task: Task<State, Swift.Error>) {
        self.channel = channel
        self.task = task
    }

    public convenience init(
        initialState: @escaping (Channel<Action>) async -> State,
        buffering: AsyncStream<Action>.Continuation.BufferingPolicy = .bufferingOldest(1),
        onStartup: UnsafeContinuation<Void, Never>? = .none,
        onCancel: @Sendable @escaping () -> Void = { },
        onCompletion: @escaping (State, Completion) async -> Void = { _, _ in },
        disposer: @escaping (Action) -> Void = { _ in },
        reducer: @escaping (inout State, Action) async throws -> Void
    ) {
        let localChannel = Channel<Action>(buffering: buffering)
        let cancellation: @Sendable () -> Void = { localChannel.finish(); onCancel() }
        let localTask = Task<State, Swift.Error> {
            try await withTaskCancellationHandler(handler: cancellation) {
                var state = await initialState(localChannel)
                onStartup?.resume()
                for await action in localChannel {
                    guard !Task.isCancelled else { break }
                    do { try await reducer(&state, action) }
                    catch {
                        localChannel.finish();
                        for await action in localChannel { disposer(action); continue }
                        await onCompletion(state, .failure(error));
                        throw error
                    }
                }
                guard !Task.isCancelled else {
                    localChannel.finish();
                    for await action in localChannel { disposer(action); continue }
                    await onCompletion(state, .cancel(state))
                    throw PublisherError.cancelled
                }
                await onCompletion(state, .termination(state))
                return state
            }
        }
        self.init(channel: localChannel, task: localTask)
    }
}

public extension StateTask {
    @inlinable
    var isCancelled: Bool { task.isCancelled }

    @Sendable func cancel() -> Void {
        task.cancel()
    }

    @Sendable func finish() -> Void {
        channel.finish()
    }

    @Sendable func yield(_ element: Action) -> AsyncStream<Action>.Continuation.YieldResult {
        channel.yield(element)
    }

    @Sendable func send(_ element: Action) -> AsyncStream<Action>.Continuation.YieldResult {
        channel.yield(element)
    }

    @inlinable
    var result: Result<State, Swift.Error> {
        get async {
            do {
                return .success(try await finalState)
            } catch {
                return .failure(error)
            }
        }
    }

    @inlinable
    var finalState: State {
        get async throws { try await task.value }
    }
}
