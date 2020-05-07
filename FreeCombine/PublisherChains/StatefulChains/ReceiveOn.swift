//
//  ReceiveOn.swift
//  FreeCombine
//
//  Created by Van Simmons on 4/25/20.
//  Copyright © 2020 ComputeCycles, LLC. All rights reserved.
//

import Foundation

extension Subscriber {
    static func join(
        _ opQueue: OperationQueue
    ) -> (Self) -> (Self) {
        let ref = Reference<Demand>(.max(1))
        return { downstream in
            .init { supply in
                ref.value = ref.value.decremented
                opQueue.addOperation { ref.value = downstream(supply) }
                return ref.value
            }
        }
    }
}

public extension Publisher {
    func receiveOn(
        _ opQueue: OperationQueue
    ) -> Publisher<Output, Failure> {
        transformation(
            joinSubscriber: Subscriber<Output, Failure>.join(opQueue),
            transformSupply: identity
        )
    }
}
