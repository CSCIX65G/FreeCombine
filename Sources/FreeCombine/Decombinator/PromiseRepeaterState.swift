//
//  PromiseRepeaterState.swift
//
//
//  Created by Van Simmons on 5/7/22.
//

public struct PromiseRepeaterState<ID: Hashable & Sendable, Output: Sendable>: Identifiable, Sendable {
    public enum Action {
        case complete(Result<Output, Swift.Error>, Semaphore<[ID], RepeatedAction<ID>>)
    }

    public let id: ID
    let downstream: @Sendable (Result<Output, Swift.Error>) async throws -> Void

    public init(
        id: ID,
        downstream: @Sendable @escaping (Result<Output, Swift.Error>) async throws -> Void
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
                await semaphore.decrement(with: .repeated(id, .done))
                return .completion(.exit)
        }
    }
}
