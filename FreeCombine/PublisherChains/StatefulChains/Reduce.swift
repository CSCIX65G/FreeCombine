//
//  Reduce.swift
//  FreeCombine
//
//  Created by Van Simmons on 4/25/20.
//  Copyright © 2020 ComputeCycles, LLC. All rights reserved.
//

extension Subscriber {
    static func join(
        _ initial: Value,
        _ next: @escaping (Value, Value) -> Value
    ) -> (Self) -> (Self) {
        let ref = Reference<Value>(initial)
        return { downstream in
            .init { supply in
                switch supply {
                case .value(let value):
                    ref.value = next(ref.value, value)
                    return .unlimited
                case .none, .failure:
                    return downstream(supply)
                case .finished:
                    _ = downstream(.value(ref.value))
                    return downstream(.finished)
                }
            }
        }
    }
}

public extension Publisher {
    func reduce(
        _ initial: Output,
        _ reduce: @escaping (Output, Output) -> Output
    ) -> Publisher<Output, Failure> {
        transformation(
            joinSubscriber: Subscriber<Output, Failure>.join(initial, reduce),
            transformSupply: identity,
            transformDemand: {
                switch $0 {
                case .cancel: return .cancel
                default: return .unlimited
                }
            }
        )
    }
}
