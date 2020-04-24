//
//  Subscriber+Inits.swift
//  FreeCombine
//
//  Created by Van Simmons on 4/20/20.
//  Copyright © 2020 ComputeCycles, LLC. All rights reserved.
//

extension Subscriber: CallableAsFunction {
    public typealias A = Publication<Value, Failure>
    public typealias B = Demand
    
    public init(_ f: Func<Publication<Value, Failure>, Demand>) {
        self.call = f.call
    }
}
