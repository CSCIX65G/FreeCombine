//
//  TryRemoveDuplicates.swift
//  
//
//  Created by Van Simmons on 7/3/22.
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
        .init { resumption, downstream in
            let deduplicator = Deduplicator<Output>(predicate)
            return self(onStartup: resumption) { r in
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
