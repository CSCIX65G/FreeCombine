//
//  Publisher+FlatMap.swift
//  FreeCombine
//
//  Created by Van Simmons on 4/17/20.
//  Copyright © 2020 ComputeCycles, LLC. All rights reserved.
//

// TODO: Implement flatMap
//public extension Publisher {
public extension Publisher {
    fileprivate struct FlatMapState<T> {
        var subscription = Optional<Subscription>.none
        var demand = Demand.max(1)
    }
    
//    func flatMap<T>(
//        _ transform: @escaping (Output) -> Publisher<T, Failure>
//    ) -> Publisher<T, Failure> {
//        transforming(
//            initialState: FlatMapState<T>(),
//            joinSubscriber: { ref in         /// Block sending unincluded downstream
//                { downstream in
//                    .init { (publication) -> Demand in
//                        switch publication {
//                        case .value(let value):
//                            let subscription = transform(value)(downstream)
//                            subscription(.demand(ref.state.demand))
//                        case .none, .failure, .finished:
//                            return downstream(publication)
//                        }
//                    }
//                }
//            },
//            preSubscriber: { _ in identity }
//        )
//    }
}


