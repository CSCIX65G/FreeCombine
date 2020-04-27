//
//  Subscriber+FlatMap.swift
//  FreeCombine
//
//  Created by Van Simmons on 4/17/20.
//  Copyright © 2020 ComputeCycles, LLC. All rights reserved.
//

extension Subscriber {
    /*:
     Prepending a new subscriber to another subscriber
     in such a way that the prepended subscriber, on invocation
     with a publication, will:
     
     1. forward the publication to the original subscriber
     2. iterate over a producer as long as a) the producer can
        produce and b) the original subscriber returns additional
        demand.
     
     This is used to `contraFlatMap` and `Subscriber` into a `Producer`
     */
    static func join(_ producer: Producer<Value, Failure>) -> (Self) -> Self {
        return { subscriber in
            var hasCompleted = false
            return .init { publication in
                var demand = subscriber(publication)
                guard demand.quantity > 0 && !hasCompleted else { return .none }
                while demand.quantity > 0 {
                    let subsequentPublication = producer(Request.demand(demand))
                    switch subsequentPublication {
                    case .none:
                        return subscriber(.none)
                    case .value:
                        demand = subscriber(subsequentPublication)
                    case .finished, .failure:
                        hasCompleted = true
                        return subscriber(subsequentPublication)
                    }
                }
                return demand
            }
        }
    }
}
