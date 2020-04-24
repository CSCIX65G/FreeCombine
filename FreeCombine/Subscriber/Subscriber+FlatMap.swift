//
//  Subscriber+FlatMap.swift
//  FreeCombine
//
//  Created by Van Simmons on 4/17/20.
//  Copyright © 2020 ComputeCycles, LLC. All rights reserved.
//

extension Subscriber {
    var joinBySubstitution: Self {
        var demand = Demand.none
        return .init(
            Func<Publication<Value, Failure>, Demand>.init { input in
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
        )
    }
    
    func contraFlatMap<T>(
        _ join: (Self) -> Self,
        _ transform: @escaping (T) -> Publication<Value, Failure>
    ) -> Func<T, Demand> {
        .init(transform >>> join(self))
    }
}
