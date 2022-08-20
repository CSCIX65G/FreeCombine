//
//  Semaphore.swift
//
//
//  Created by Van Simmons on 4/24/22.
//  Derived from: https://github.com/apple/swift-atomics/blob/main/Tests/AtomicsTests/LockFreeSingleConsumerStack.swift
//  As per, the Apache license this is a derivative work.
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

class SingleConsumerStack<Element> {
    struct Node {
        let value: Element
        var next: UnsafeMutablePointer<Node>?
    }
    typealias NodePtr = UnsafeMutablePointer<Node>

    private var _last = UnsafeAtomic<NodePtr?>.create(nil)
    private var _consumerCount = UnsafeAtomic<Int>.create(0)
    private var foo = 0

    deinit {
        // Discard remaining nodes
        while let _ = pop() { }
        _last.destroy()
        _consumerCount.destroy()
    }

    // Push the given element to the top of the stack.
    // It is okay to concurrently call this in an arbitrary number of threads.
    func push(_ value: Element) {
        let new = NodePtr.allocate(capacity: 1)
        new.initialize(to: Node(value: value, next: nil))

        var done = false
        var current = _last.load(ordering: .relaxed)
        while !done {
            new.pointee.next = current
            (done, current) = _last.compareExchange(
                expected: current,
                desired: new,
                ordering: .releasing
            )
        }
    }

    // Pop and return the topmost element from the stack.
    // This method does not support multiple overlapping concurrent calls.
    func pop() -> Element? {
        guard _consumerCount.loadThenWrappingIncrement(ordering: .acquiring) == 0 else {
            return .none
        }
        defer { _consumerCount.wrappingDecrement(ordering: .releasing) }
        var done = false
        var current = _last.load(ordering: .acquiring)
        while let c = current {
            (done, current) = _last.compareExchange(
                expected: c,
                desired: c.pointee.next,
                ordering: .acquiring
            )
            if done {
                let result = c.move()
                c.deallocate()
                return result.value
            }
        }
        return nil
    }
}
