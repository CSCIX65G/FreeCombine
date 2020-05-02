//
//  Subscriber+FlatMap.swift
//  FreeCombine
//
//  Created by Van Simmons on 4/17/20.
//  Copyright © 2020 ComputeCycles, LLC. All rights reserved.
//

extension Subscriber {
    /*:
     Wrapping a producer in a subscriber
     in such a way that the new subscriber, will now
     accept Demands for invocation.  On
     invocation the new subscriber will:
     
     1. forward the demand to the producer
     2. iterate over the producer as long as a) the producer can
        produce and b) the original subscriber returns additional
        demand.
     
     This is used to `contraFlatMap` a `Subscriber` over a `Producer`
     */
    static func producerJoin(
        _ producer: Producer<Value, Failure>
    ) -> (Self) -> Self {
        let ref = Reference<Demand>(.max(1))
        return { downstreamSubscriber in
            var hasCompleted = false
            return .init { supply in
                // TODO: This should be flatMap on Supply
                var demand = downstreamSubscriber(supply)
                while demand.quantity > 0 && !hasCompleted {
                    let nextSupply = producer(demand)
                    switch nextSupply {
                    case .none:
                        return ref.value
                    case .value, .failure:
                        demand = ref.set(downstreamSubscriber(nextSupply))
                    case .finished:
                        hasCompleted = true
                        return downstreamSubscriber(nextSupply)
                    }
                }
                return demand
            }
        }
    }
}
