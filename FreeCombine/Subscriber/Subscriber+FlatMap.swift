//
//  Subscriber+FlatMap.swift
//  FreeCombine
//
//  Created by Van Simmons on 4/17/20.
//  Copyright © 2020 ComputeCycles, LLC. All rights reserved.
//

extension Subscriber {
    static func contraFlatMap<T>(
        _ generator: @escaping (Self, T) -> Subscriber<T, Failure>,
        _ start: @escaping (Subscriber<T, Failure>) -> (T) -> (Demand)
    ) -> (Self) -> Subscriber<T, Failure> {
        { subscriber in
            return .init(
                input: { start(generator(subscriber, $0))($0) },
                completion: subscriber.completion
            )
        }
    }
//
//    static func contraFlatMapError<T: Error>(
//        _ start: Self,
//        _ transform: @escaping (T) -> Failure,
//        _ completion: @escaping Com
//    ) -> (Self) -> Subscriber<T, Failure> {
//        { subscriber in
//            .init(
//                input: subscriber.input,
//                completion: completion
//            )
//        }
//    }
}
