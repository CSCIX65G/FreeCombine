//
//  Counter.swift
//  
//
//  Created by Van Simmons on 3/1/22.
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
        while !atomicValue.compareExchange(
            expected: c,
            desired: c + by,
            ordering: .sequentiallyConsistent
        ).0 {
            c = atomicValue.load(ordering: .sequentiallyConsistent)
        }
        return c + by
    }

    @discardableResult
    public func decrement(by: Int = 1) -> Int {
        var c = atomicValue.load(ordering: .sequentiallyConsistent)
        while !atomicValue.compareExchange(
            expected: c,
            desired: c - by,
            ordering: .sequentiallyConsistent
        ).0 {
            c = atomicValue.load(ordering: .sequentiallyConsistent)
        }
        return c - by
    }
}
