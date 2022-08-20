//
//  TryRemoveDuplicates.swift
//  
//
//  Created by Van Simmons on 7/3/22.
//
fileprivate class Deduplicator<A> {
    let isEquivalent: (A, A) async throws -> Bool
    var currentValue: A!

    init(_ predicate: @escaping (A, A) async throws -> Bool) {
        self.isEquivalent = predicate
    }

    func forward(
        value: A,
        with downstream: (AsyncStream<A>.Result) async throws -> Demand
    ) async throws -> Demand {
        guard let current = currentValue else {
            currentValue = value
            return try await downstream(.value(value))
        }
        guard !(try await isEquivalent(value, current)) else {
            return .more
        }
        currentValue = value
        return try await downstream(.value(value))
    }
}

extension Publisher where Output: Equatable {
    func tryRemoveDuplicates() -> Publisher<Output> {
        removeDuplicates(by: ==)
    }
}

extension Publisher {
    func tryRemoveDuplicates(
        by predicate: @escaping (Output, Output) async throws -> Bool
    ) -> Publisher<Output> {
        .init { continuation, downstream in
            let deduplicator = Deduplicator<Output>(predicate)
            return self(onStartup: continuation) { r in
                guard !Task.isCancelled else {
                    return try await handleCancellation(of: downstream)
                }
                switch r {
                    case .value(let a):
                        do { return try await deduplicator.forward(value: a, with: downstream) }
                        catch { return try await handleCancellation(of: downstream) }
                    case .completion(.failure(let e)):
                        return try await downstream(.completion(.failure(e)))
                    case .completion(.finished), .completion(.cancelled):
                        return try await downstream(r)
                }
            }
        }
    }
}
