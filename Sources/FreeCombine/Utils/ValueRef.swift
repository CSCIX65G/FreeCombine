//
//  ValueRef.swift
//  
//
//  Created by Van Simmons on 5/18/22.
//

public actor ValueRef<Value> {
    var value: Value
    
    public init(value: Value) { self.value = value }

    @discardableResult
    public func set(value: Value) -> Value {
        let tmp = self.value
        self.value = value
        return tmp
    }
}

extension ValueRef {
    public func append<T>(_ t: T) where Value == [T] {
        value.append(t)
    }

    public func next<T, U>() -> U? where Value == IndexingIterator<T>, T.Element == U {
        value.next()
    }
}

