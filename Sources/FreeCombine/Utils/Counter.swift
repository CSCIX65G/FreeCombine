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
    public func value(resetAt value: Int) -> Int {
        let tmpCount = count
        guard tmpCount != value else {
            count = 0
            return tmpCount
        }
        return count
    }
}
