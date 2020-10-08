//
//  Reduce.swift
//  FreeCombine
//
//  Created by Van Simmons on 4/25/20.
//  Copyright © 2020 ComputeCycles, LLC. All rights reserved.
//

extension Subscriber {
    static func join(
        _ initial: Value
    ) -> (Self) -> (Self) {
        var ref = initial
        return { downstream in
            .init { supply in
                switch supply {
                    case .value(let value):
                        ref = value
                        return .unlimited
                    case .none, .failure:
                        return downstream(supply)
                    case .finished:
                        _ = downstream(.value(ref))
                        return downstream(.finished)
                }
            }
        }
    }
}

public extension Publisher {
    func reduce<Accum>(
        _ initial: Accum,
        _ reduce: @escaping (Accum) -> (Output) -> Accum
    ) -> Publisher<Accum, Failure> {
        let accum: Accum = initial
        return transformation(
            joinSubscriber: Subscriber<Accum, Failure>.join(initial),
            transformSupply: Supply.map(reduce(accum)),
            transformDemand: {
                switch $0 {
                    case .cancel: return .cancel
                    default: return .unlimited
                }
            }
        )
    }
}
