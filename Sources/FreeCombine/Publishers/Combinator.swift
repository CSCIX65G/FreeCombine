//
//  Combinator.swift
//  
//
//  Created by Van Simmons on 5/8/22.
//
public protocol CombinatorState {
    associatedtype CombinatorAction
    var mostRecentDemand: Demand { get }
}

public func Combinator<Output: Sendable, State: CombinatorState, Action>(
    initialState: @escaping (@escaping (AsyncStream<Output>.Result) async throws -> Demand) -> (Channel<Action>) async -> State,
    buffering: AsyncStream<Action>.Continuation.BufferingPolicy,
    onCancel: @escaping () -> Void,
    onCompletion: @escaping (inout State, Reducer<State, Action>.Completion) async -> Void,
    reducer: Reducer<State, Action>
) -> Publisher<Output> where State.CombinatorAction == Action {
    .init(
        initialState: initialState,
        buffering: buffering,
        onCancel: onCancel,
        onCompletion: onCompletion,
        reducer: reducer
    )
}

public extension Publisher {
    init<State: CombinatorState, Action>(
        initialState: @escaping (@escaping (AsyncStream<Output>.Result) async throws -> Demand) -> (Channel<Action>) async -> State,
        buffering: AsyncStream<Action>.Continuation.BufferingPolicy,
        onCancel: @escaping () -> Void,
        onCompletion: @escaping (inout State, Reducer<State, Action>.Completion) async -> Void,
        reducer: Reducer<State, Action>
    ) where State.CombinatorAction == Action {
        self = .init { continuation, downstream in
            .init {
                let stateTask = await StateTask.stateTask(
                    initialState: initialState(downstream),
                    buffering: buffering,
                    onCompletion: onCompletion,
                    reducer: reducer
                )

                return try await withTaskCancellationHandler(handler: {
                    stateTask.cancel()
                    onCancel()
                }) {
                    guard continuation != nil else { fatalError("Should have a continuation here") }
                    continuation?.resume()
                    guard !Task.isCancelled else { throw PublisherError.cancelled }
                    let finalState = try await stateTask.finalState
                    let mostRecentDemand = finalState.mostRecentDemand
                    return mostRecentDemand
                }
            }
        }
    }
}
