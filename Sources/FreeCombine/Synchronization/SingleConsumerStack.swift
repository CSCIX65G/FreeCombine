//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift Atomics open source project
//
// Copyright (c) 2020-2021 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//
import Atomics

class LockFreeSingleConsumerStack<Element> {
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
        while let _ = pop() {}
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
                ordering: .releasing)
        }
    }

    // Pop and return the topmost element from the stack.
    // This method does not support multiple overlapping concurrent calls.
    func pop() -> Element? {
        precondition(
            _consumerCount.loadThenWrappingIncrement(ordering: .acquiring) == 0,
            "Multiple consumers detected"
        )
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
