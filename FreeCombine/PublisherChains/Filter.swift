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
            joinSubscriber: { ref in   /// Block sending .none downstream
                { downstream in
                    .init { (publication) -> Demand in
                        switch publication {
                        case .none: return ref.state
                        case .value, .failure, .finished: return downstream(publication)
                        }
                    }
                }
            },
            preSubscriber: { _ in     /// check the value received, convert it to .none if it doesn't pass
                { upstreamPublication in
                    switch upstreamPublication {
                    case .value(let value):
                        return isIncluded(value) ? upstreamPublication : .none
                    case .none, .failure, .finished: return upstreamPublication
                    }
                }
            },
            postSubscriber: { ref in   /// save the demand state so that we can echo it when we filter
                { demand in
                    ref.state = demand; return demand
                }
            }
        )
    }
}
