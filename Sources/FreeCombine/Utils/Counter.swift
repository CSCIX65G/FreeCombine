//
//  Counter.swift
//  
//
//  Created by Van Simmons on 3/1/22.
//
import Atomics

public struct Counter {
    private let atomicValue: ManagedAtomic<Int> = .init(0)

    public init(count: Int = 0) {
        self.atomicValue.store(count, ordering: .relaxed)
    }

    public var count: Int {
        return atomicValue.load(ordering: .sequentiallyConsistent)
    }

    @discardableResult
    public func increment(by: Int = 1) -> Int {
        var c = atomicValue.load(ordering: .sequentiallyConsistent)
        while !atomicValue.compareExchange(expected: c, desired: c + by, ordering: .sequentiallyConsistent).0 {
            c = atomicValue.load(ordering: .sequentiallyConsistent)
        }
        return c + by
    }

    @discardableResult
    public func decrement(by: Int = -1) -> Int {
        var c = atomicValue.load(ordering: .sequentiallyConsistent)
        while !atomicValue.compareExchange(expected: c, desired: c - by, ordering: .sequentiallyConsistent).0 {
            c = atomicValue.load(ordering: .sequentiallyConsistent)
        }
        return c - by
    }
}
