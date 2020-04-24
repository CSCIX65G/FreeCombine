//
//  FreeCombine.swift
//  FreeCombine
//
//  Created by Van Simmons on 4/6/20.
//  Copyright © 2020 ComputeCycles, LLC. All rights reserved.
//

public enum Demand {
    case none
    case max(Int)
    case unlimited
    case last

    var quantity: Int {
        switch self {
        case .none: return 0
        case .max(let val): return val
        case .unlimited: return Int.max
        case .last: return 0
        }
    }
}

public enum Request {
    case demand(Demand)
    case cancel
}

public enum Publication<Value, Failure: Error> {
    case none
    case value(Value)
    case failure(Failure)
    case finished
}

public struct Producer<Value, Failure: Error> {
    public var call: (Request) -> Publication<Value, Failure>
}

public struct Subscriber<Value, Failure: Error> {
    public let call: (Publication<Value, Failure>) -> Demand
    public init(_ call: @escaping (Publication<Value, Failure>) -> Demand) {
        self.call = call
    }
}

public final class Subscription {
    public let call: (Request) -> Void
    public init(_ call: @escaping (Request) -> Void) {
        self.call = call
    }
}

public struct Publisher<Output, Failure: Error> {
    public let call: (Subscriber<Output, Failure>) -> Subscription
}
