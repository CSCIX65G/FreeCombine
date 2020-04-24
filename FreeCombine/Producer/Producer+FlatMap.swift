//
//  Producer+FlatMap.swift
//  FreeCombine
//
//  Created by Van Simmons on 4/18/20.
//  Copyright © 2020 ComputeCycles, LLC. All rights reserved.
//

extension Producer {
    func bind(subscriber: Subscriber<Value, Failure>) -> (Request) -> Demand {
        var hasCompleted = false
        return { request in
            guard case .demand(let demand) = request else {
                return subscriber(.finished)
            }
            guard demand.quantity > 0 && !hasCompleted else { return .none }
            var newDemand = demand
            while newDemand.quantity > 0 {
                let supply = self(request)
                switch supply {
                case .none:
                    return subscriber(.none)
                case .value:
                    newDemand = subscriber(supply)
                case .finished, .failure:
                    hasCompleted = true
                    return subscriber(supply)
                }
            }
            return newDemand
        }
    }
}
