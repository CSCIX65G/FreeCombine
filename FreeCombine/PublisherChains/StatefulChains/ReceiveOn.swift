//
//  ReceiveOn.swift
//  FreeCombine
//
//  Created by Van Simmons on 4/25/20.
//  Copyright © 2020 ComputeCycles, LLC. All rights reserved.
//

import Foundation

extension Subscriber {
    static func receiveOnJoin(
        _ opQueue: OperationQueue
    ) -> (Self) -> (Self) {
        let ref = Reference<Demand>(.max(1))
        return { downstream in
            .init { publication in
                ref.state = .max(ref.state.quantity - 1)
                opQueue.addOperation {
                    _ = ref.save(downstream(publication))
                }
                return ref.state
            }
        }
    }
}

public extension Publisher {
    func receiveOn(
        _ opQueue: OperationQueue
    ) -> Publisher<Output, Failure> {
        transformation(
            joinSubscriber: Subscriber<Output, Failure>.receiveOnJoin(opQueue),
            transformPublication: identity
        )
    }
}
