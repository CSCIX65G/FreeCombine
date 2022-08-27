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

    public enum Error: Swift.Error {
        case completed
        case internalError
        case cancelled
    }

    let reducer: (inout State, Action) async throws -> Effect
    let disposer: (Action, Completion) async -> Void
    let finalizer: (inout State,Completion) async -> Void

    public init(
        reducer: @escaping (inout State, Action) async throws -> Effect,
        disposer: @escaping (Action, Completion) async -> Void = { _, _ in },
        finalizer: @escaping (inout State, Completion) async -> Void = { _, _ in }
    ) {
        self.finalizer = finalizer
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
        await finalizer(&state, completion)
    }
}

extension Reducer {
    func reduce(
        state: inout State,
        action: Action,
        channel: Channel<Action>,
        effects: inout Set<Cancellable<Demand>>
    ) async throws -> Void {
        switch try await reducer(&state, action) {
            case .none: ()
            case .completion(.exit): throw Error.completed
            case .completion(let .failure(error)): throw error
            case .completion(.finished): throw Error.internalError
            case .completion(.cancel): throw Error.cancelled
            case .published(let publisher):
                await publisher.sink { action in
                    channel.yield(action)
                }.store(in: &effects)
        }
    }

    func dispose(
        channel: Channel<Action>,
        error: Swift.Error
    ) async throws -> Void {
        channel.finish()
        for await action in channel.stream {
            switch error {
                case Error.completed:
                    await self(action, .finished); continue
                case Error.cancelled:
                    await self(action, .cancel); continue
                default:
                    await self(action, .failure(error)); continue
            }
        }
    }

    func finalize(
        state: inout State,
        error: Swift.Error
    ) async throws -> Void {
        guard let completion = error as? Error else {
            await self(&state, .failure(error))
            throw error
        }
        switch completion {
            case .cancelled:
                await self(&state, .cancel)
                throw completion
            case .completed:
                await self(&state, .exit)
            case .internalError:
                await self(&state, .failure(PublisherError.internalError))
                throw completion
        }
    }

    func finalize(_ state: inout State, _ completion: Completion) async -> Void {
        await finalizer(&state, completion)
    }
}

extension Reducer where State == Void {
    init(
        disposer: @escaping (Action, Completion) -> Void = { _, _ in },
        reducer: @escaping (Action) async throws -> Effect
    ) {
        self.init(
            reducer: { _, action in try await reducer(action) },
            disposer: disposer
        )
    }
}
