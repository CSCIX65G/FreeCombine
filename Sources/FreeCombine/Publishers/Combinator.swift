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
    onCompletion: @escaping (State, StateTask<State, Action>.Completion) async -> Void,
    operation: @escaping (inout State, Action) async throws -> Void
) -> Publisher<Output> where State.CombinatorAction == Action {
    .init(
        initialState: initialState,
        buffering: buffering,
        onCancel: onCancel,
        onCompletion: onCompletion,
        operation: operation
    )
}

public extension Publisher {
    init<State: CombinatorState, Action>(
        initialState: @escaping (@escaping (AsyncStream<Output>.Result) async throws -> Demand) -> (Channel<Action>) async -> State,
        buffering: AsyncStream<Action>.Continuation.BufferingPolicy,
        onCancel: @escaping () -> Void,
        onCompletion: @escaping (State, StateTask<State, Action>.Completion) async -> Void,
        operation: @escaping (inout State, Action) async throws -> Void
    ) where State.CombinatorAction == Action {
        self = .init { continuation, downstream in
            .init {
                let stateTask = await StateTask.stateTask(
                    initialState: initialState(downstream),
                    buffering: buffering,
                    onCompletion: onCompletion,
                    reducer: operation
                )

                return try await withTaskCancellationHandler(handler: {
                    stateTask.cancel()
                    onCancel()
                }) {
                    continuation?.resume()
                    guard !Task.isCancelled else {
                        throw Publisher<Output>.Error.cancelled
                    }
                    return try await stateTask.finalState.mostRecentDemand
                }
            }
        }
    }
}
