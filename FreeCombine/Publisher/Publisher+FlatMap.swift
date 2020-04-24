//
//  Publisher+FlatMap.swift
//  FreeCombine
//
//  Created by Van Simmons on 4/17/20.
//  Copyright © 2020 ComputeCycles, LLC. All rights reserved.
//

//public extension Publisher {
//    typealias FlatMapPublisher<T> =
//        Publisher<Output, OutputControl, OutputFailure, T, OutputControl, OutputFailure>
//    
//    func flatMap<T>(
//        _ transform: @escaping (Output) -> FlatMapPublisher<T>
//    ) -> FlatMapPublisher<T> {
//        var remainingDemand = .none
//        
//        FlatMapPublisher<T>(
//            hoist: Subscriber.contraFlatMap(
//                { (subscriber, value) in
//                    (value |> transform).receive(subscriber: Subscriber<T, Error>(
//                        input: .init({ (<#T#>) -> Demand in
//                            <#code#>
//                        })
//                    ))
//                },
//                { (<#Subscriber<T, _>#>) -> (T) -> (Demand) in
//                    <#code#>
//            }
//            ),
//            convert: receive,
//            lower: identity
//        )
//    }
//}
