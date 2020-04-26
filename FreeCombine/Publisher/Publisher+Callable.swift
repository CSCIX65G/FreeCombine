//
//  Publisher+Callable.swift
//  FreeCombine
//
//  Created by Van Simmons on 4/25/20.
//  Copyright © 2020 ComputeCycles, LLC. All rights reserved.
//

extension Publisher: CallableAsFunction {
    public init(_ f: Func<Subscriber<Output, Failure>, Subscription>) {
        self.call = f.call
    }
}
