//
//  ReplaceEmpty.swift
//  
//
//  Created by Van Simmons on 7/3/22.
//
import Atomics
public extension Publisher {
    func replaceEmpty(
        with value: Output
    ) -> Self {
        .init { continuation, downstream in
            let isEmpty = ManagedAtomic<Bool>(true)
            return self(onStartup: continuation) { r in switch r {
                case .value(let a):
                    isEmpty.store(false, ordering: .sequentiallyConsistent)
                    return try await downstream(.value(a))
                case let .completion(completion):
                    if isEmpty.load(ordering: .sequentiallyConsistent) {
                        _ = try await downstream(.value(value))
                    }
                    return try await downstream(.completion(completion))
            } }
        }
    }
}
