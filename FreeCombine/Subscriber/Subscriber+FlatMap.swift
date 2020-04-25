//
//  Subscriber+FlatMap.swift
//  FreeCombine
//
//  Created by Van Simmons on 4/17/20.
//  Copyright © 2020 ComputeCycles, LLC. All rights reserved.
//

extension Subscriber {
    var join: Self {
        var demand = Demand.none
        return .init { input in
            switch input {
            case .finished:
                return demand
            case .value, .failure:
                demand = self(input)
                return demand
            case .none:
                return .last
            }
        }
    }
    
    static func join(_ producer: Producer<Value, Failure>) -> (Self) -> Self {
        return { subscriber in
            var hasCompleted = false
            return .init { pub in
                var demand = subscriber(pub)
                guard demand.quantity > 0 && !hasCompleted else { return .none }
                while demand.quantity > 0 {
                    let supply = producer(Request.demand(demand))
                    switch supply {
                    case .none:
                        return subscriber(.none)
                    case .value:
                        demand = subscriber(supply)
                    case .finished, .failure:
                        hasCompleted = true
                        return subscriber(supply)
                    }
                }
                return demand
            }
        }
    }
    
    func contraFlatMap<T>(
        _ join: (Self) -> Self,
        _ transform: @escaping (T) -> Publication<Value, Failure>
    ) -> Func<T, Demand> {
        .init(transform >>> join(self))
    }
}
