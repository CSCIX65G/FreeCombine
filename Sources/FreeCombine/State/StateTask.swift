//
//  StateTask.swift
//  
//  Created by Van Simmons on 2/17/22.
//
/*:
 #actor problems

 1. no oneway funcs (can't call from synchronous code)
 2. can't selectively block callers (to pass a continuation to an actor requires spawning a task which gives up ordering guarantees)
 3. can't block calling tasks on internal state (can only block with async call to another task)
 4. no concept of cancellation (cannot perform orderly shutdown with outstanding requests in flight)
 5. execute on global actor queues (generally not needed or desirable)
 6. No way of possible failure to enqueue on an overburdened actor, all requests enter an unbounded queue

 #actor solutions: StateTask - a swift implementation of the Haskell ST monad

 1. LOCK FREE CHANNELS
 2. Haskell translation: ∀s in Rank-N types becomes a Task
 3. Use explicit queues to process events

 # statetask action requirements:

 2. sendable funcs
 3. routable
 4. value types
 5. some actions are blocking, these need special handling (think DO oneway keyword)
 */

public final class StateTask<State, Action: Sendable> {
    let file: StaticString
    let line: UInt
    let deinitBehavior: DeinitBehavior
    let channel: Channel<Action>
    let cancellable: Cancellable<State>

    fileprivate init(
        file: StaticString = #file,
        line: UInt = #line,
        deinitBehavior: DeinitBehavior = .assert,
        channel: Channel<Action>,
        cancellable: Cancellable<State>
    ) {
        self.file = file
        self.line = line
        self.deinitBehavior = deinitBehavior
        self.channel = channel
        self.cancellable = cancellable
    }

    deinit {
        let shouldCancel = !(cancellable.isCancelled || cancellable.isCompleting)
        switch deinitBehavior {
            case .assert:
                assert(!shouldCancel, "ABORTING DUE TO LEAKED \(type(of: Self.self)) CREATED @ \(file): \(line)")
            case .logAndCancel:
                if shouldCancel { print("CANCELLING LEAKED \(type(of: Self.self)) CREATED @ \(file): \(line)") }
            case .silentCancel:
                ()
        }
        if shouldCancel { cancellable.cancel() }
    }

    public var isCancelled: Bool {
        @Sendable get {
            cancellable.isCancelled
        }
    }

    public var isCompleting: Bool {
        @Sendable get {
            cancellable.isCompleting
        }
    }

    public var value: State {
        get async throws {
            try await cancellable.value
        }
    }

    var result: Result<State, Swift.Error> {
        get async {
            do { return .success(try await value) }
            catch { return .failure(error) }
        }
    }

    @Sendable func send(_ element: Action) -> AsyncStream<Action>.Continuation.YieldResult {
        channel.yield(element)
    }

    @Sendable func finish() -> Void {
        channel.finish()
    }

    @Sendable func finishAndAwaitResult() async -> Result<State, Swift.Error> {
        channel.finish()
        return await cancellable.result
    }

    @Sendable func finishAndAwaitValue() async throws -> State {
        channel.finish()
        return try await cancellable.value
    }

    @Sendable func cancel() -> Void {
        cancellable.cancel()
    }

    @Sendable func cancelAndAwaitResult() async -> Result<State, Swift.Error> {
        cancellable.cancel()
        return await cancellable.result
    }

    @Sendable func cancelAndAwaitValue() async throws -> State {
        cancellable.cancel()
        return try await cancellable.value
    }
}

extension StateTask {
    private enum Error: Swift.Error {
        case completed
        case internalError
        case cancelled
    }
    public convenience init(
        file: StaticString = #file,
        line: UInt = #line,
        deinitBehavior: DeinitBehavior = .assert,
        channel: Channel<Action>,
        initialState: @escaping (Channel<Action>) async -> State,
        onStartup: Resumption<Void>,
        reducer: Reducer<State, Action>
    ) {
        self.init (
            file: file,
            line: line,
            deinitBehavior: deinitBehavior,
            channel: channel,
            cancellable: .init(file: file, line: line, deinitBehavior: deinitBehavior) {
                var state = await initialState(channel)
                onStartup.resume()
                do { try await withTaskCancellationHandler(handler: channel.finish) {
                    for await action in channel {
                        let effect = try await reducer(&state, action)
                        switch effect {
                            case .none: continue
                            case .published(_):
                                // FIXME: Need to handle the publisher, i.e. channel.consume(publisher: publisher)
                                continue
                            case .completion(.exit): throw Error.completed
                            case let .completion(.failure(error)): throw error
                            case .completion(.finished): throw Error.internalError
                            case .completion(.cancel):
                                throw Error.cancelled
                        }
                    }
                    await reducer(&state, .finished)
                } } catch {
                    channel.finish()
                    for await action in channel {
                        switch error {
                            case Error.completed:
                                await reducer(action, .finished); continue
                            case Error.cancelled:
                                await reducer(action, .cancel); continue
                            default:
                                await reducer(action, .failure(error)); continue
                        }
                    }
                    guard let completion = error as? Error else {
                        await reducer(&state, .failure(error))
                        throw error
                    }
                    switch completion {
                        case .cancelled:
                            await reducer(&state, .cancel)
                            throw completion
                        case .completed:
                            await reducer(&state, .exit)
                        case .internalError:
                            await reducer(&state, .failure(PublisherError.internalError))
                            throw completion
                    }
                }
                return state
            }
        )
    }
}

public extension StateTask {
    static func stateTask(
        file: StaticString = #file,
        line: UInt = #line,
        deinitBehavior: DeinitBehavior = .assert,
        channel: Channel<Action>,
        initialState: @escaping (Channel<Action>) async -> State,
        reducer: Reducer<State, Action>
    ) async -> Self {
        var stateTask: Self!
        try! await withResumption(file: file, line: line, deinitBehavior: deinitBehavior) { stateTaskContinuation in
            stateTask = Self.init(
                channel: channel,
                initialState: initialState,
                onStartup: stateTaskContinuation,
                reducer: reducer
            )
        }
        return stateTask
    }
}
