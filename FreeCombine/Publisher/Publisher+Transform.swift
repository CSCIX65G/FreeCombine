//
//  Publisher+Transform.swift
//  FreeCombine
//
//  Created by Van Simmons on 4/27/20.
//  Copyright © 2020 ComputeCycles, LLC. All rights reserved.
//

extension Publisher {
    func transforming<State, Downstream, DownstreamFailure>(
        initialState: State,
        preSubscriber: @escaping (inout State) -> (Publication<Output, Failure>) -> Publication<Downstream, DownstreamFailure>,
        postSubscriber: @escaping (inout State) -> (Demand) -> Demand,
        preSubscription: @escaping (inout State) -> (Request) -> Request,
        postSubscription: @escaping (inout State) -> () -> Void
    ) -> Publisher<Downstream, DownstreamFailure> {
        var state = initialState
        
        let hoist = { (downstream: Subscriber<Downstream, DownstreamFailure>) -> Subscriber<Output, Failure> in
            .init(downstream.dimap(preSubscriber(&state), postSubscriber(&state)))
        }
        
        let lower = { (upstream: Subscription) -> Subscription in
            Subscription.init(upstream.dimap(preSubscription(&state), postSubscription(&state)))
        }

        return .init(dimap(hoist, lower))
    }
}
