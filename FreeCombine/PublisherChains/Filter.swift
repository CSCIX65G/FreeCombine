//
//  Filter.swift
//  FreeCombine
//
//  Created by Van Simmons on 4/26/20.
//  Copyright © 2020 ComputeCycles, LLC. All rights reserved.
//

//public extension Publisher {
//    func filter(_ transform: @escaping (Output) -> Bool) -> Publisher<Output, Failure> {
//        struct FilterState {
//            var hasFailed = false
//            demand = Demand.none
//        }
//        transforming(
//            initialState: Demand.none,
//            preSubscriber: { state in
//                { upstreamPublication in
//                    switch upstreamPublication {
//                        
//                    }
//                }
//            },
//            postSubscriber: { state in { newDemand in state = newDemand } },
//            preSubscription: { _ in identity },
//            postSubscription: { _ in { } }
//        )
//    }
//}
