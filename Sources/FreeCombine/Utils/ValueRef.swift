//
//  ValueRef.swift
//  
//
//  Created by Van Simmons on 5/18/22.
//

public actor ValueRef<Value> {
    var value: Value
    public init(value: Value) { self.value = value }
    public func set(value: Value) { self.value = value }
}
