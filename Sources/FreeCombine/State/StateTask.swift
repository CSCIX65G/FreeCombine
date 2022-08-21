//
//  StateTask.swift
//  
//  Created by Van Simmons on 2/17/22.
//
//  Copyright 2022, ComputeCycles, LLC
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

/*:
 # Actor Problems

 1. no oneway funcs (i.e. they can’t be called from synchronous code)
 2. can’t selectively block callers in order (i.e. passing a continuation to an actor requires spawning a task which gives up ordering guarantees)
 3. can’t block calling tasks on internal state (can only block with async call to another task)
 4. have no concept of cancellation (cannot perform orderly shutdown with outstanding requests in flight)
 5. they execute on global actor queues (generally not needed or desirable to go off-Task for these things)
 6. No way to allow possible failure to enqueue on an overburdened actor, all requests enter an unbounded queue

 # Actor Solutions: StateTask - a swift implementation of the Haskell ST monad

 From: [Lazy Functional State Threads](https://www.microsoft.com/en-us/research/wp-content/uploads/1994/06/lazy-functional-state-threads.pdf)

 1. LOCK FREE CHANNELS
 2. Haskell translation: ∀s in Rank-N types becomes a Task
 3. Use explicit queues to process events

 # StateTask Action Requirements:

 1. Sendable funcs
 2. routable
 3. value types
 4. some actions are blocking, these need special handling (think DO oneway keyword)

 From: [SE-304 Structured Concurrency](https://github.com/apple/swift-evolution/blob/main/proposals/0304-structured-concurrency.md#structured-concurrency-1)
 > Systems that rely on queues are often susceptible to queue-flooding, where the queue accepts more work than it can actually handle. This is typically solved by introducing "back-pressure": a queue stops accepting new work, and the systems that are trying to enqueue work there respond by themselves stopping accepting new work. Actor systems often subvert this because it is difficult at the scheduler level to refuse to add work to an actor's queue, since doing so can permanently destabilize the system by leaking resources or otherwise preventing operations from completing. Structured concurrency offers a limited, cooperative solution by allowing systems to communicate up the task hierarchy that they are coming under distress, potentially allowing parent tasks to stop or slow the creation of presumably-similar new work.

 FreeCombines addresses this differently by allowing backpressure and explicit disposal of queued items.
 */
public final class StateTask<State, Action: Sendable> {
    let channel: Channel<Action>
    let cancellable: Cancellable<State>

    public let function: StaticString
    public let file: StaticString
    public let line: UInt
    public let deinitBehavior: DeinitBehavior

    fileprivate init(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line,
        deinitBehavior: DeinitBehavior = .assert,
        channel: Channel<Action>,
        cancellable: Cancellable<State>
    ) {
        self.function = function
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
                assert(!shouldCancel, "ABORTING DUE TO LEAKED \(type(of: Self.self))  CREATED in \(function) @ \(file): \(line)")
            case .logAndCancel:
                if shouldCancel { print("CANCELLING LEAKED \(type(of: Self.self))  CREATED in \(function) @ \(file): \(line)") }
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

    private static func reduce(
        state: inout State,
        action: Action,
        reducer: Reducer<State, Action>
    ) async throws -> Void {
        switch try await reducer(&state, action) {
            case .none: ()
            case .completion(.exit): throw Error.completed
            case .completion(let .failure(error)): throw error
            case .completion(.finished): throw Error.internalError
            case .completion(.cancel): throw Error.cancelled
            case .published(let publisher):
                await publisher.sink { action in

                }
        }
    }

    private static func dispose(
        channel: Channel<Action>,
        reducer: Reducer<State, Action>,
        error: Swift.Error
    ) async throws -> Void {
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
    }

    private static func finalize(
        state: inout State,
        reducer: Reducer<State, Action>,
        error: Swift.Error
    ) async throws -> Void {
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

    public convenience init(
        function: StaticString = #function,
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
                    // Loop over the channel, reducing each action into state
                    for await action in channel {
                        try await Self.reduce(state: &state, action: action, reducer: reducer)
                    }
                    // Finalize state given upstream finish
                    await reducer(&state, .finished)
                } } catch {
                    // Dispose of any pending actions since downstream has finished
                    try await Self.dispose(channel: channel, reducer: reducer, error: error)
                    // Finalize the state given downstream finish
                    try await Self.finalize(state: &state, reducer: reducer, error: error)
                }
                return state
            }
        )
    }
}

public extension StateTask {
    static func stateTask(
        function: StaticString = #function,
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
