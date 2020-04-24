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

    public convenience init(_ f: Func<Request, Void>) {
        self.init(f.call)
    }
}
