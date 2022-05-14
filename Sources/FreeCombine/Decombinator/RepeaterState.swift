//
//  Repeater.swift
//  
//
//  Created by Van Simmons on 5/7/22.
//

public enum RepeatedAction<ID: Hashable & Sendable>: Sendable {
    case repeated(ID, Demand)
}

public struct RepeaterState<ID: Hashable & Sendable, Output: Sendable>: Identifiable {
    public enum Action {
        case `repeat`(AsyncStream<Output>.Result, Semaphore<[ID], RepeatedAction<ID>>)
    }

    public let id: ID
    let downstream: (AsyncStream<Output>.Result) async throws -> Demand
    var mostRecentDemand: Demand

    public init(
        id: ID,
        downstream: @escaping (AsyncStream<Output>.Result) async throws -> Demand,
        mostRecentDemand: Demand = .more
    ) async {
        self.id = id
        self.downstream = downstream
        self.mostRecentDemand = mostRecentDemand
    }

    static func reduce(`self`: inout Self, action: Self.Action) async throws -> Void {
        try await `self`.reduce(action: action)
    }

    mutating func reduce(action: Self.Action) async throws -> Void {
        switch action {
            case let .repeat(output, semaphore):
                mostRecentDemand = (try? await downstream(output)) ?? .done
                return await semaphore.decrement(with: .repeated(id, mostRecentDemand))
        }
    }
}
