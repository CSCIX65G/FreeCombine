//
//  ValueRef.swift
//  
//
//  Created by Van Simmons on 5/18/22.
//

public actor ValueRef<Value> {
    enum Error: Swift.Error {
        case occupied
    }
    public private(set) var value: Value

    public init(value: Value) { self.value = value }

    @discardableResult
    public func set(value: Value) -> Value {
        let tmp = self.value
        self.value = value
        return tmp
    }

    public func get() -> Value {
        return self.value
    }
}

extension ValueRef {
    public func append<T>(_ t: T) where Value == [T] {
        value.append(t)
    }
}

extension ValueRef {
    public func swapIfNone<T>(_ t: T) throws -> Void where Value == T? {
        guard value == nil else { throw Error.occupied }
        value = t
    }
}

