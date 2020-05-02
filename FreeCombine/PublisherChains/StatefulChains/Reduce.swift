//
//  Reduce.swift
//  FreeCombine
//
//  Created by Van Simmons on 4/25/20.
//  Copyright © 2020 ComputeCycles, LLC. All rights reserved.
//

extension Subscriber {
    static func reducerJoin(
        _ initial: Value,
        _ next: @escaping (Value, Value) -> Value
    ) -> (Self) -> (Self) {
        let ref = Reference<Value>(initial)
        return { downstream in
            .init { publication in
                switch publication {
                case .value(let value):
                    _ = ref.save(next(ref.state, value))
                    return .unlimited
                case .none, .failure:
                    return downstream(publication)
                case .finished:
                    _ = downstream(.value(ref.state))
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
            joinSubscriber: Subscriber<Output, Failure>.reducerJoin(initial, reduce),
            transformPublication: identity,
            transformRequest: {
                switch $0 {
                case .cancel: return .cancel
                case .demand: return .demand(.unlimited)
                }
            }
        )
    }
}
