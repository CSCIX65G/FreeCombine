//
//  Repeater.swift
//  
//
//  Created by Van Simmons on 5/7/22.
//

enum DistributorAction<ID: Hashable> {
    case resume(ID, Demand)
}

fileprivate struct RepeaterState<ID: Hashable, Output: Sendable>: Identifiable {
    typealias CombinatorAction = Self.Action

    enum Action {
        case send(AsyncStream<Output>.Result, Semaphore<[ID], DistributorAction<ID>>)
    }

    let id: ID
    let downstream: (AsyncStream<Output>.Result) async throws -> Demand

    init(
        id: ID,
        downstream: @escaping (AsyncStream<Output>.Result) async throws -> Demand
    ) async {
        self.id = id
        self.downstream = downstream
    }

    static func create() -> (@escaping (AsyncStream<Output>.Result) async throws -> Demand) -> (ID) async -> Self {
        { downstream in { id in await .init(id: id, downstream: downstream) } }
    }

    static func complete(state: Self, completion: StateTask<Self, Self.Action>.Completion) -> Void {
    }

    static func reduce(`self`: inout Self, action: Self.Action) async throws -> Void {
        try await `self`.reduce(action: action)
    }

    mutating func reduce(action: Self.Action) async throws -> Void {
        switch action {
            case let .send(output, semaphore):
                let demand = try? await downstream(output)
                await semaphore.decrement(with: .resume(id, demand ?? .done))
                return
        }
    }

    mutating func resume(returning demand: Demand) {
    }

    mutating func terminate(with completion: Completion) async throws -> Void {
        resume(returning: .done)
    }
}
