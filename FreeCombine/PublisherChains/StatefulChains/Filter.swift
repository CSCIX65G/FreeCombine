//
//  Filter.swift
//  FreeCombine
//
//  Created by Van Simmons on 4/26/20.
//  Copyright © 2020 ComputeCycles, LLC. All rights reserved.
//

extension Subscriber {
    static func filterJoin(
        _ test: @escaping (Value) -> Bool
    ) -> (Self) -> (Self) {
        let ref = Reference<Demand>(.max(1))
        return { downstream in
            .init { supply in
                switch supply {
                case .value(let value):
                    return test(value)
                        ? ref.set(downstream(supply))
                        : ref.value
                case .none, .failure:
                    return downstream(supply)
                case .finished:
                    return ref.value
                }
            }
        }
    }
}

public extension Publisher {
    func filter(
        _ isIncluded: @escaping (Output) -> Bool
    ) -> Publisher<Output, Failure> {
        return transformation(
            joinSubscriber: Subscriber<Output, Failure>.filterJoin(isIncluded),
            transformSupply: identity
        )
    }
}
