//
//  Callable.swift
//  FreeCombine
//
//  Created by Van Simmons on 5/2/20.
//  Copyright © 2020 ComputeCycles, LLC. All rights reserved.
//
extension Subscriber: CallableAsFunction {
    public typealias A = Supply<Value, Failure>
    public typealias B = Demand
    public init(_ f: Func<Supply<Value, Failure>, Demand>) {
        self.call = f.call
    }
    public init<C>(_ c: C) where C : CallableAsFunction, Self.A == C.A, Self.B == C.B {
        self.call = c.call
    }
}

extension Subscription: CallableAsFunction {
    public typealias A = Demand
    public typealias B = Void    
    public init(_ f: Func<Demand, Void>) {
        self.call = f.call
    }
    public init<C>(_ c: C) where C : CallableAsFunction, Self.A == C.A, Self.B == C.B {
        self.call = c.call
    }
}

extension Producer: CallableAsFunction {
    public typealias A = Demand
    public typealias B = Supply<Value, Failure>
    public init<C>(_ c: C) where C : CallableAsFunction, Self.A == C.A, Self.B == C.B {
        self.call = c.call
    }
}

extension Publisher: CallableAsFunction {
    public typealias A = Subscriber<Output, Failure>
    public typealias B = Subscription
        public init(_ f: Func<A, B>) {
        self.call = f.call
    }
    public init<C>(_ c: C) where C : CallableAsFunction, Self.A == C.A, Self.B == C.B {
        self.call = c.call
    }
}
