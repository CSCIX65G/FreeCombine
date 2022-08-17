//
//  AtomicValueRef.swift
//  
//
//  Created by Van Simmons on 8/16/22.
//
import Atomics

class AtomicValueRef<Element> {
    enum Error: Swift.Error {
        case cantExchange
    }

    struct Node {
        let sequence: Int
        let value: Element?
    }

    typealias NodePtr = UnsafeMutablePointer<Node>

    private var _value = UnsafeAtomic<NodePtr?>.create(nil)
    private var _currentSequence = UnsafeAtomic<Int>.create(0)

    deinit {
        _value.destroy()
    }

    func set(_ value: Element?) throws -> Void {
        let current = _value.load(ordering: .relaxed)
        let sequence = current?.pointee.sequence ?? 0
        let new = NodePtr.allocate(capacity: 1)
        new.initialize(to: Node(sequence: sequence + 1, value: value))

        let (done, _) = _value.compareExchange(
            expected: current,
            desired: new,
            ordering: .releasing
        )
        guard done else { throw Error.cantExchange }
    }

    func get() -> Element? {
        return _value.load(ordering: .relaxed)?.pointee.value
    }
}
