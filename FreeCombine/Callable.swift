//
//  Callable.swift
//  FreeCombine
//
//  Created by Van Simmons on 5/2/20.
//  Copyright © 2020 ComputeCycles, LLC. All rights reserved.
//

extension Publisher: CallableAsFunction {
    public typealias A = Subscriber<Output, Failure>
    public typealias B = Subscription
    
    public init(_ f: Func<Subscriber<Output, Failure>, Subscription>) {
        self.call = f.call
    }
}

extension Subscriber: CallableAsFunction {
    public typealias A = Supply<Value, Failure>
    public typealias B = Demand
    
    public init(_ f: Func<Supply<Value, Failure>, Demand>) {
        self.call = f.call
    }
}

extension Subscription: CallableAsFunction {
    public typealias A = Demand
    public typealias B = Void

    public init(_ f: Func<Demand, Void>) {
        self.init(f.call)
    }
}

extension Producer: CallableAsFunction {
    public typealias A = Demand
    public typealias B = Supply<Value, Failure>
    
    public init(_ f: Func<Demand, Supply<Value, Failure>>) {
        self.call = f.call
    }
}
