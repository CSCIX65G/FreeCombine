//
//  RemoveDuplicates.swift
//  
//
//  Created by Van Simmons on 5/23/22.
//

fileprivate actor Deduplicator<A> {
    let predicate: (A, A) -> Bool
    var currentValue: A!

    init(_ predicate: @escaping (A, A) -> Bool) {
        self.predicate = predicate
    }

    func forward(
        value: A,
        with downstream: (AsyncStream<A>.Result) async throws -> Demand
    ) async throws -> Demand {
        guard let current = currentValue else {
            currentValue = value
            return try await downstream(.value(value))
        }
        guard !(predicate(value, current)) else {
            return .more
        }
        currentValue = value
        return try await downstream(.value(value))
    }
}

extension Publisher where Output: Equatable {
    func removeDuplicates() -> Publisher<Output> {
        removeDuplicates(by: ==)
    }
}

extension Publisher {
    func removeDuplicates(
        by predicate: @escaping (Output, Output) -> Bool
    ) -> Publisher<Output> {
        .init { continuation, downstream in
            let deduplicator = Deduplicator<Output>(predicate)
            return self(onStartup: continuation) { r in
                guard !Task.isCancelled else {
                    return try await downstream(.completion(.failure(PublisherError.cancelled)))
                }
                switch r {
                    case .value(let a):
                        return try await deduplicator.forward(value: a, with: downstream)
                    case .completion(.failure(let e)):
                        return try await downstream(.completion(.failure(e)))
                    case .completion(.finished):
                        return try await downstream(.completion(.finished))
                }
            }
        }
    }
}
