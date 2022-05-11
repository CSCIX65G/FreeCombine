//
//  Repeater.swift
//  
//
//  Created by Van Simmons on 5/7/22.
//

enum RepeaterAction<ID: Hashable & Sendable>: Sendable {
    case repeated(ID, Demand)
}

struct RepeaterState<ID: Hashable & Sendable, Output: Sendable>: Identifiable {
    enum Action {
        case `repeat`(AsyncStream<Output>.Result, Semaphore<[ID], RepeaterAction<ID>>)
    }

    let id: ID
    let downstream: (AsyncStream<Output>.Result) async throws -> Demand
    var mostRecentDemand: Demand

    init(
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
