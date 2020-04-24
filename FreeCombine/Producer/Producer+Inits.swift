//
//  Producer+Inits.swift
//  FreeCombine
//
//  Created by Van Simmons on 4/20/20.
//  Copyright © 2020 ComputeCycles, LLC. All rights reserved.
//

extension Producer: CallableAsFunction {
    public typealias A = Request
    public typealias B = Publication<Value, Failure>
    
    public init(_ call: @escaping (Request) -> Publication<Value, Failure>) {
        self.call = call
    }
    
    public init(_ f: Func<Request, Publication<Value, Failure>>) {
        self.call = f.call
    }
}
