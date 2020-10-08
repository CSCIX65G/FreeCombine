//
//  Filter.swift
//  FreeCombine
//
//  Created by Van Simmons on 4/26/20.
//  Copyright © 2020 ComputeCycles, LLC. All rights reserved.
//

extension Subscriber {
    static func join(
        _ test: @escaping (Value) -> Bool
    ) -> (Self) -> (Self) {
        var ref = Demand.max(1)
        return { downstream in
            .init { supply in
                switch supply {
                    case .value(let value):
                        ref = test(value) ? downstream(supply) : ref
                        return ref
                    case .none, .failure:
                        return downstream(supply)
                    case .finished:
                        return ref
                }
            }
        }
    }
}

public extension Publisher {
    func filter(
        _ isIncluded: @escaping (Output) -> Bool
    ) -> Publisher<Output, Failure> {
        transformation(
            joinSubscriber: Subscriber<Output, Failure>.join(isIncluded),
            transformSupply: identity
        )
    }
}
