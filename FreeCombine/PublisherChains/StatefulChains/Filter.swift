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
        let ref = StateRef<Demand>(.max(1))
        return { downstream in
            .init { publication in
                switch publication {
                case .value(let value):
                    return test(value)
                        ? ref.save(downstream(publication))
                        : ref.state
                case .none, .failure:
                    return downstream(publication)
                case .finished:
                    return ref.state
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
            transformPublication: identity
        )
    }
}
