//
//  Counter.swift
//  
//
//  Created by Van Simmons on 3/1/22.
//

public actor Counter {
    public private(set) var count = 0

    public init() { }

    @discardableResult
    public func increment() -> Int {
        count += 1
        return count
    }
    @discardableResult
    public func decrement() -> Int {
        count -= 1
        return count
    }
}
