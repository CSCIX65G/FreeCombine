//
//  Subscription+Init.swift
//  FreeCombine
//
//  Created by Van Simmons on 4/18/20.
//  Copyright © 2020 ComputeCycles, LLC. All rights reserved.
//

extension Subscription: CallableAsFunction {
    public typealias A = Request
    public typealias B = Void

    public init(_ f: Func<Request, Void>) {
        self.init(f.call)
    }

    public init(_ f: Func<Request, Demand>) {
        self.init(f.map(void).call)
    }
}
