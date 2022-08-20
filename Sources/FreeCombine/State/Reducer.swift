//
//  Reducer.swift
//  
//
//  Created by Van Simmons on 5/25/22.
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
public struct Reducer<State, Action> {
    public enum Effect {
        case none
        case published(Publisher<Action>)
        case completion(Completion)
    }

    public enum Completion {
        case finished
        case exit
        case failure(Swift.Error)
        case cancel
    }

    let disposer: (Action, Completion) async -> Void
    let reducer: (inout State, Action) async throws -> Effect
    let onCompletion: (inout State,Completion) async -> Void

    public init(
        onCompletion: @escaping (inout State, Completion) async -> Void = { _, _ in },
        disposer: @escaping (Action, Completion) async -> Void = { _, _ in },
        reducer: @escaping (inout State, Action) async throws -> Effect
    ) {
        self.onCompletion = onCompletion
        self.disposer = disposer
        self.reducer = reducer
    }

    public func callAsFunction(_ state: inout State, _ action: Action) async throws -> Effect {
        try await reducer(&state, action)
    }

    public func callAsFunction(_ action: Action, _ completion: Completion) async -> Void {
        await disposer(action, completion)
    }

    public func callAsFunction(_ state: inout State, _ completion: Completion) async -> Void {
        await onCompletion(&state, completion)
    }
}

extension Reducer where State == Void {
    init(
        disposer: @escaping (Action, Completion) -> Void = { _, _ in },
        reducer: @escaping (Action) async throws -> Effect
    ) {
        self.init(
            disposer: disposer,
            reducer: { _, action in try await reducer(action) }
        )
    }
}
