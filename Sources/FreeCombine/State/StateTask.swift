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

public enum StateTaskError: Swift.Error, Sendable, CaseIterable {
    case cancelled
    case completed
}

public final class StateTask<State, Action: Sendable> {
//    public enum Effect {
//        case none
//        case fireAndForget(() -> Void)
//        case published(Action)
//        case completion(Completion)
//    }
//
//    public enum Completion {
//        case termination(State)
//        case exit(State)
//        case failure(Swift.Error)
//        case cancel(State)
//    }
//
    let channel: Channel<Action>
    let task: Task<State, Swift.Error>

    deinit {
        task.cancel()
    }

    init(channel: Channel<Action>, task: Task<State, Swift.Error>) {
        self.channel = channel
        self.task = task
    }

    public convenience init(
        channel: Channel<Action>,
        initialState: @escaping (Channel<Action>) async -> State,
        onStartup: UnsafeContinuation<Void, Never>? = .none,
        onCancel: @Sendable @escaping () -> Void = { },
        onCompletion: @escaping (inout State, Reducer<State, Action>.Completion) async -> Void = { _, _ in },
        reducer: Reducer<State, Action>
    ) {
        self.init(
            channel: channel,
            task: .init { try await withTaskCancellationHandler(handler: onCancel) {
                var state = await initialState(channel)
                onStartup?.resume()
                do {
                    for await action in channel {
                        guard !Task.isCancelled else { throw StateTaskError.cancelled }
                        _ = try await reducer(&state, action)
                    }
                    await onCompletion(&state, .termination(state))
                } catch {
                    channel.finish()
                    for await action in channel { reducer(action, error); continue }
                    guard let completion = error as? StateTaskError else {
                        await onCompletion(&state, .failure(error)); throw error
                    }
                    switch completion {
                        case .cancelled:
                            await onCompletion(&state, .cancel(state))
                            throw completion
                        case .completed:
                            await onCompletion(&state, .exit(state))
                    }
                }
                return state
            } }
        )
    }

    public var isCancelled: Bool {
        task.isCancelled
    }

    public var finalState: State {
        get async throws {
            try await task.value
        }
    }
}

public extension StateTask {
    @Sendable func cancel() -> Void {
        task.cancel()
    }

    @Sendable func finish() -> Void {
        channel.finish()
    }

    @Sendable func send(_ element: Action) -> AsyncStream<Action>.Continuation.YieldResult {
        channel.yield(element)
    }

    var result: Result<State, Swift.Error> {
        get async {
            do { return .success(try await finalState) }
            catch { return .failure(error) }
        }
    }
}
