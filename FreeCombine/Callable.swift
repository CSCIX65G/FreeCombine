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
}

extension Subscriber: CallableAsFunction {
    public typealias A = Supply<Value, Failure>
    public typealias B = Demand
}

extension Subscription: CallableAsFunction {
    public typealias A = Demand
    public typealias B = Void
}

extension Producer: CallableAsFunction {
    public typealias A = Demand
    public typealias B = Supply<Value, Failure>
}
