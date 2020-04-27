//
//  Filter.swift
//  FreeCombine
//
//  Created by Van Simmons on 4/26/20.
//  Copyright © 2020 ComputeCycles, LLC. All rights reserved.
//

public extension Publisher {
    func filter(
        _ isIncluded: @escaping (Output) -> Bool
    ) -> Publisher<Output, Failure> {
        transforming(
            initialState: Demand.none,
            joinSubscriber: { ref in
                { downstream in
                    .init { (publication) -> Demand in
                        switch publication {
                        case .none: return ref.state
                        case .value, .failure, .finished: return downstream(publication)
                        }
                    }
                }
            },
            preSubscriber: { _ in
                { upstreamPublication in
                    switch upstreamPublication {
                    case .value(let value):
                        return isIncluded(value) ? upstreamPublication : .none
                    case .none, .failure, .finished: return upstreamPublication
                    }
                }
            },
            postSubscriber: { ref in
                { demand in
                    ref.state = demand; return demand
                }
            }
        )
    }
}
