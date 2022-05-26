//
//  Reducer.swift
//  
//
//  Created by Van Simmons on 5/25/22.
//

public struct Reducer<State, Action> {
    public enum Effect {
        case none
        case fireAndForget(() -> Void)
        case published(Action)
        case completion(Completion)
    }

    public enum Completion {
        case termination
        case exit
        case failure(Swift.Error)
        case cancel
    }

    let disposer: (Action, Error) -> Void
    let reducer: (inout State, Action) async throws -> Effect

    public init(
        disposer: @escaping (Action, Error) -> Void = { _, _ in },
        reducer: @escaping (inout State, Action) async throws -> Effect
    ) {
        self.disposer = disposer
        self.reducer = reducer
    }

    public func callAsFunction(_ state: inout State, _ action: Action) async throws -> Effect {
        try await reducer(&state, action)
    }

    public func callAsFunction(_ action: Action, _ error: Error) -> Void {
        disposer(action, error)
    }
}

extension Reducer where State == Void {
    init(
        disposer: @escaping (Action, Error) -> Void = { _, _ in },
        reducer: @escaping (Action) async throws -> Effect
    ) {
        self.init(
            disposer: disposer,
            reducer: { _, action in try await reducer(action) }
        )
    }
}
