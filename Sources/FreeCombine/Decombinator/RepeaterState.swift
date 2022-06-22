//
//  Repeater.swift
//  
//
//  Created by Van Simmons on 5/7/22.
//

public enum RepeatedAction<ID: Hashable & Sendable>: Sendable {
    case repeated(ID, Demand)
}

public struct RepeaterState<ID: Hashable & Sendable, Output: Sendable>: Identifiable, Sendable {
    public enum Action {
        case `repeat`(AsyncStream<Output>.Result, Semaphore<[ID], RepeatedAction<ID>>)
    }

    public let id: ID
    let downstream: @Sendable (AsyncStream<Output>.Result) async throws -> Demand
    var mostRecentDemand: Demand

    public init(
        id: ID,
        downstream: @Sendable @escaping (AsyncStream<Output>.Result) async throws -> Demand,
        mostRecentDemand: Demand = .more
    ) {
        self.id = id
        self.downstream = downstream
        self.mostRecentDemand = mostRecentDemand
    }

    static func complete(state: inout Self, completion: Reducer<Self, Self.Action>.Completion) async -> Void {
        do {
            switch completion {
                case .finished:
                    _ = try await state.downstream(.completion(.finished))
                case .exit:
                    ()
                case let .failure(error):
                    _ = try await state.downstream(.completion(.failure(error)))
                case .cancel:
                    _ = try await state.downstream(.completion(.cancelled))
            }
        } catch { }
    }

    static func reduce(`self`: inout Self, action: Self.Action) async throws -> Reducer<Self, Action>.Effect {
        try await `self`.reduce(action: action)
    }

    mutating func reduce(action: Self.Action) async throws -> Reducer<Self, Action>.Effect {
        switch action {
            case let .repeat(output, semaphore):
                do {
                    mostRecentDemand = try await downstream(output)
                    if case .completion = output { mostRecentDemand = .done }
                }
                catch { mostRecentDemand = .done }
                await semaphore.decrement(with: .repeated(id, mostRecentDemand))
                return mostRecentDemand == .done ? .completion(.exit) : .none
        }
    }
}
