//
//  Callable.swift
//  FreeCombine
//
//  Created by Van Simmons on 5/2/20.
//  Copyright © 2020 ComputeCycles, LLC. All rights reserved.
//

extension Publisher: CallableAsFunction {
    public init(_ f: Func<Subscriber<Output, Failure>, Subscription>) {
        self.call = f.call
    }
}

extension Subscriber: CallableAsFunction {
    public typealias A = Publication<Value, Failure>
    public typealias B = Demand
    
    public init(_ f: Func<Publication<Value, Failure>, Demand>) {
        self.call = f.call
    }
}

extension Subscription: CallableAsFunction {
    public typealias A = Request
    public typealias B = Void

    public init(_ f: Func<Request, Void>) {
        self.init(f.call)
    }
}

extension Producer: CallableAsFunction {
    public typealias A = Request
    public typealias B = Publication<Value, Failure>
    
    public init(_ f: Func<Request, Publication<Value, Failure>>) {
        self.call = f.call
    }
}
