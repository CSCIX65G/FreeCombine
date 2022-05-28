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

 #actor solutions: StateTask - a swift implementation of the Haskell ST monad

 1. LOCK FREE CHANNELS
 2. Haskell translation: ∀s in Rank-N types becomes a Task

 # statetask actions:

 2. sendable funcs
 3. routable
 4. value types
 5. some actions are blocking, these need special handling (think DO oneway keyword)
 */

public final class StateTask<State, Action: Sendable> {
    let channel: Channel<Action>
    let task: Task<State, Swift.Error>

    fileprivate init(channel: Channel<Action>, task: Task<State, Swift.Error>) {
        self.channel = channel
        self.task = task
    }

    deinit { task.cancel() }

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

extension StateTask {
    public convenience init(
        channel: Channel<Action>,
        initialState: @escaping (Channel<Action>) async -> State,
        onStartup: UnsafeContinuation<Void, Never>? = .none,
        onCancel: @Sendable @escaping () -> Void = { },
        reducer: Reducer<State, Action>
    ) {
        self.init(
            channel: channel,
            task: .init { try await withTaskCancellationHandler(handler: onCancel) {
                var state = await initialState(channel)
                onStartup?.resume()
                do {
                    for await action in channel {
                        guard !Task.isCancelled else {
                            await reducer(&state, .cancel)
                            throw PublisherError.cancelled
                        }
                        switch try await reducer(&state, action) {
                            case .none: continue
                            case .published(_): continue // FIXME: Handle future mutation
                            case .completion(.exit): throw PublisherError.completed
                            case let .completion(.failure(error)): throw error
                            case .completion(.termination): throw PublisherError.internalError
                            case .completion(.cancel): throw PublisherError.cancelled
                        }
                    }
                    await reducer(&state, .termination)
                } catch {
                    channel.finish()
                    for await action in channel {
                        reducer(action, .failure(error))
                        continue
                    }
                    guard let completion = error as? PublisherError else {
                        await reducer(&state, .failure(error)); throw error
                    }
                    switch completion {
                        case .cancelled:
                            await reducer(&state, .cancel)
                            throw completion
                        case .completed:
                            await reducer(&state, .exit)
                        case .internalError:
                            fatalError("StateTask internal error")
                        case .enqueueError:
                            fatalError("Enqueue error from upstream")
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
    static func stateTask(
        channel: Channel<Action>,
        initialState: @escaping (Channel<Action>) async -> State,
        onCancel: @Sendable @escaping () -> Void = { },
        reducer: Reducer<State, Action>
    ) async -> Self {
        var stateTask: Self!
        await withUnsafeContinuation { stateTaskContinuation in
            stateTask = Self.init(
                channel: channel,
                initialState: initialState,
                onStartup: stateTaskContinuation,
                onCancel: onCancel,
                reducer: reducer
            )
        }
        return stateTask
    }
}
