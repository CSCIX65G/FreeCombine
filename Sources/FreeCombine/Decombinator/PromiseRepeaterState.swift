//
//  PromiseRepeaterState.swift
//
//
//  Created by Van Simmons on 5/7/22.
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
public struct PromiseRepeaterState<ID: Hashable & Sendable, Output: Sendable>: Identifiable, Sendable {
    public enum Action {
        case complete(Result<Output, Swift.Error>, Semaphore<[ID], RepeatedAction<ID>>)
    }

    public let id: ID
    let downstream: @Sendable (Result<Output, Swift.Error>) async throws -> Void

    public init(
        id: ID,
        downstream: @escaping @Sendable (Result<Output, Swift.Error>) async throws -> Void
    ) {
        self.id = id
        self.downstream = downstream
    }

    static func complete(state: inout Self, completion: Reducer<Self, Self.Action>.Completion) async -> Void {
        do {
            switch completion {
                case .finished:
                    ()
                case .exit:
                    ()
                case let .failure(error):
                    _ = try await state.downstream(.failure(error))
                case .cancel:
                    _ = try await state.downstream(.failure(PublisherError.cancelled))
            }
        } catch { }
    }

    static func reduce(`self`: inout Self, action: Self.Action) async throws -> Reducer<Self, Action>.Effect {
        try await `self`.reduce(action: action)
    }

    mutating func reduce(action: Self.Action) async throws -> Reducer<Self, Action>.Effect {
        switch action {
            case let .complete(output, semaphore):
                    try? await downstream(output)
                semaphore.decrement(with: .repeated(id, .done))
                return .completion(.exit)
        }
    }
}
