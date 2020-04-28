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
        flatMapTransformation(
            initialState: Demand.max(1),
            joinSubscriber: { ref in
                { downstream in
                    .init { (publication) -> Demand in
                        switch publication {
                        case .value(let value):
                            return isIncluded(value) ? ref.save(downstream(publication)) : ref.state
                        case .none, .failure, .finished:
                            return downstream(publication)
                        }
                    }
                }
            },
            transformPublication: { _ in identity }
        )
    }
}