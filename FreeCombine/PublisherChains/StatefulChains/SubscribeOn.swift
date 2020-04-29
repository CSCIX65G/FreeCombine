//
//  SubscribeOn.swift
//  FreeCombine
//
//  Created by Van Simmons on 4/25/20.
//  Copyright © 2020 ComputeCycles, LLC. All rights reserved.
//

import Foundation

extension Subscription {
    static func subscribeOnJoin(
        _ opQueue: OperationQueue
    ) -> (Self) -> (Self) {
        return { upstream in
            .init { request in
                opQueue.addOperation {
                    _ = upstream(request)
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
            transformPublication: identity,
            joinSubscription: Subscription.subscribeOnJoin(opQueue)
        )
    }
}
