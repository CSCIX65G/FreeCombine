//
//  Reducer.swift
//  
//
//  Created by Van Simmons on 5/25/22.
//

struct Reducer<State, Action> {
    public enum Effect {
        case none
        case fireAndForget(() -> Void)
        case published(Action)
        case completion(Completion)
    }

    public enum Completion {
        case termination(State)
        case exit(State)
        case failure(Swift.Error)
        case cancel(State)
    }

    let disposer: (Action, Error) -> Void = { _, _ in }
    let reducer: (inout State, Action) async throws -> Effect
}
