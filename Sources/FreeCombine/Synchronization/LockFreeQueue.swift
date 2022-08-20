//
//  LockFreeQueue.swift
//  
//
//  Created by Van Simmons on 8/20/22.
//  Derived from: https://github.com/apple/swift-atomics/blob/main/Tests/AtomicsTests/LockFreeQueue.swift
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
// A lock-free concurrent queue implementation adapted from
// M. Michael and M. Scott's 1996 paper [Michael 1996].
//
// [Michael 1996]: https://doi.org/10.1145/248052.248106
//
// While this is a nice illustration of the use of atomic strong references,
// this is a somewhat sloppy implementation of an old algorithm. If you need a
// lock-free queue for actual production use, it would probably be a good idea
// to look at some more recent algorithms before deciding on this one.
//
// Note: because this implementation uses reference counting, we don't need
// to implement a free list to resolve the original algorithm's use-after-free
// problem.

import Atomics

private let nodeCount = ManagedAtomic<Int>(0)

class LockFreeQueue<Element> {
    final class Node: AtomicReference {
        let next: ManagedAtomic<Node?>
        var value: Element?

        init(value: Element?, next: Node?) {
            self.value = value
            self.next = ManagedAtomic(next)
            nodeCount.wrappingIncrement(ordering: .relaxed)
        }

        deinit {
            var values = 0
            // Prevent stack overflow when reclaiming a long queue
            var node = self.next.exchange(nil, ordering: .relaxed)
            while node != nil && isKnownUniquelyReferenced(&node) {
                let next = node!.next.exchange(nil, ordering: .relaxed)
                withExtendedLifetime(node) {
                    values += 1
                }
                node = next
            }
            if values > 0 {
                fatalError("Deinit of lock free queue failed to dereference values")
            }
            nodeCount.wrappingDecrement(ordering: .relaxed)
        }
    }

    let head: ManagedAtomic<Node>
    let tail: ManagedAtomic<Node>

    // Used to distinguish removed nodes from active nodes with a nil `next`.
    let marker = Node(value: nil, next: nil)

    init() {
        let dummy = Node(value: nil, next: nil)
        self.head = ManagedAtomic(dummy)
        self.tail = ManagedAtomic(dummy)
    }

    func enqueue(_ newValue: Element) {
        let new = Node(value: newValue, next: nil)
        var tail = self.tail.load(ordering: .acquiring)
        while true {
            let next = tail.next.load(ordering: .acquiring)
            if tail === marker || next === marker {
                tail = self.tail.load(ordering: .acquiring)
                continue
            }
            if let next = next {
                let (exchanged, original) = self.tail.compareExchange(
                    expected: tail,
                    desired: next,
                    ordering: .acquiringAndReleasing
                )
                tail = (exchanged ? next : original)
                continue
            }
            let (exchanged, current) = tail.next.compareExchange(
                expected: nil,
                desired: new,
                ordering: .acquiringAndReleasing
            )
            if exchanged {
                _ = self.tail.compareExchange(expected: tail, desired: new, ordering: .releasing)
                return
            }
            tail = current!
        }
    }

    func dequeue() -> Element? {
        while true {
            let head = self.head.load(ordering: .acquiring)
            let next = head.next.load(ordering: .acquiring)
            if next === marker { continue }
            guard let n = next else { return nil }
            let tail = self.tail.load(ordering: .acquiring)
            if head === tail {
                _ = self.tail.compareExchange(expected: tail, desired: n, ordering: .acquiringAndReleasing)
            }
            if self.head.compareExchange(expected: head, desired: n, ordering: .releasing).exchanged {
                let result = n.value!
                n.value = nil
                // To prevent threads that are suspended in `enqueue`/`dequeue` from
                // holding onto arbitrarily long chains of removed nodes, we unlink
                // removed nodes by replacing their `next` value with the special
                // `marker`.
                head.next.store(marker, ordering: .releasing)
                return result
            }
        }
    }
}
