//
//  Combinator.swift
//  
//
//  Created by Van Simmons on 5/4/22.
//

public enum Combinator { }

public protocol CombinatorState {
    associatedtype CombinatorAction
    var mostRecentDemand: Demand { get }
    static func complete(state: Self, completion: StateTask<Self, CombinatorAction>.Completion) -> Void
    static func reduce(`self`: inout Self, action: CombinatorAction) async throws -> Void
}

public extension Combinator {
    static func publisher<Output, State: CombinatorState, Action>(
        initialState: @escaping (@escaping (AsyncStream<Output>.Result) async throws -> Demand) -> (Channel<Action>) async -> State,
        buffering: AsyncStream<Action>.Continuation.BufferingPolicy,
        onCancel: @escaping () -> Void,
        onCompletion: @escaping (State, StateTask<State, Action>.Completion) -> Void,
        operation: @escaping (inout State, Action) async throws -> Void
    ) -> Publisher<Output> {
        .init { continuation, downstream in
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
                    guard !Task.isCancelled else { throw Publisher<Output>.Error.cancelled }
                    return try await stateTask.finalState.mostRecentDemand
                }
            }
        }
    }
}
