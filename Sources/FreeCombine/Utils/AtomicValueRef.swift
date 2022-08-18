//
//  AtomicValueRef.swift
//  
//
//  Created by Van Simmons on 8/16/22.
//
import Atomics

class AtomicValueRef<Value> {
    enum Error: Swift.Error {
        case cantExchange
    }

    struct Node {
        let sequence: Int
        var value: Value
    }

    typealias NodePtr = UnsafeMutablePointer<Node>

    private var _value: UnsafeAtomic<NodePtr>

    init(value: Value) {
        let new = NodePtr.allocate(capacity: 1)
        new.initialize(to: Node(sequence: 0, value: value))
        _value = .create(new)
    }

    deinit {
        _value.destroy()
    }

    func set(_ value: Value) throws -> Value {
        let current = _value.load(ordering: .relaxed)
        let new = NodePtr.allocate(capacity: 1)
        new.initialize(to: Node(
            sequence: current.pointee.sequence + 1,
            value: value
        ) )
        let (done, oldNode) = _value.compareExchange(
            expected: current,
            desired: new,
            ordering: .relaxed
        )
        guard done else { throw Error.cantExchange }
        let oldValue = oldNode.pointee.value
        oldNode.deallocate()
        return oldValue
    }

    func get() -> Value? {
        return _value.load(ordering: .relaxed).pointee.value
    }
}

extension AtomicValueRef {
    public func append<T>(_ t: T) throws -> Void where Value == [T] {
        let current = _value.load(ordering: .acquiring)
        let new = NodePtr.allocate(capacity: 1)
        current.pointee.value.append(t)
        new.initialize(to: Node(
            sequence: current.pointee.sequence + 1,
            value: current.pointee.value
        ) )
        let (done, oldNode) = _value.compareExchange(
            expected: current,
            desired: new,
            ordering: .releasing
        )
        guard done else { throw Error.cantExchange }
        oldNode.deallocate()
    }
}
