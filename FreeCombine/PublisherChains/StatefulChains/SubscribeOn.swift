//
//  SubscribeOn.swift
//  FreeCombine
//
//  Created by Van Simmons on 4/25/20.
//  Copyright © 2020 ComputeCycles, LLC. All rights reserved.
//

import Foundation

extension Subscription {
    static func join(
        _ opQueue: OperationQueue
    ) -> (Self) -> (Self) {
        return { upstream in
            .init { demand in
                opQueue.addOperation {
                    _ = upstream(demand)
                }
            }
        }
    }
}

public extension Publisher {
    func subscribeOn(
        _ opQueue: OperationQueue
    ) -> Publisher<Output, Failure> {
        transformation(
            transformSupply: identity,
            joinSubscription: Subscription.join(opQueue)
        )
    }
}
