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
     accept Requests for invocation.  On
     invocation the new subscriber will:
     
     1. forward the request to the producer
     2. iterate over the producer as long as a) the producer can
        produce and b) the original subscriber returns additional
        demand.
     
     This is used to `contraFlatMap` a `Subscriber` over a `Producer`
     */
    static func producerJoin(
        _ producer: Producer<Value, Failure>
    ) -> (Self) -> Self {
        let ref = StateRef<Demand>(.max(1))
        return { downstream in
            var hasCompleted = false
            return .init { publication in
                var demand = downstream(publication)
                guard demand.quantity > 0 && !hasCompleted else { return .none }
                while demand.quantity > 0 {
                    let subsequentPublication = producer(Request.demand(demand))
                    switch subsequentPublication {
                    case .none:
                        return ref.state
                    case .value:
                        demand = ref.save(downstream(subsequentPublication))
                    case .finished, .failure:
                        hasCompleted = true
                        return downstream(subsequentPublication)
                    }
                }
                return demand
            }
        }
    }
}
