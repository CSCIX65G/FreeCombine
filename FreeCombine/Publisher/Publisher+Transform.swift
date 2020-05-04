//
//  Publisher+Transform.swift
//  FreeCombine
//
//  Created by Van Simmons on 4/27/20.
//  Copyright © 2020 ComputeCycles, LLC. All rights reserved.
//

extension Publisher {
    func transformation<DI, DF>(
        joinSubscriber: @escaping (Subscriber<DI, DF>)
            -> Subscriber<DI, DF> = identity,
        transformSupply: @escaping (Supply<Output, Failure>)
            -> (Supply<DI, DF>),
        joinSubscription: @escaping (Subscription)
            -> Subscription = identity,
        transformDemand: @escaping (Demand) -> Demand = identity
    ) -> Publisher<DI, DF> {

        let hoist = { (downstream: Subscriber<DI, DF>) -> Subscriber<Output, Failure> in
            .init(downstream.contraFlatMap(joinSubscriber, transformSupply))
        }
        
        let lower = { (mySubscription: Subscription) -> Subscription in
            .init(mySubscription.contraFlatMap(joinSubscription, transformDemand))
        }

//        (DownstreamSubscriber) -> MySubscriber
//            MySubscriber -> MySubscription
//                MySubscription -> DownstreamSubscription
        return .init(dimap(hoist, lower))
    }
}
