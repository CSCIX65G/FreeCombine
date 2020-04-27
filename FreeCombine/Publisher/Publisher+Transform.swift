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
        joinSubscriber: @escaping (inout State)
            -> (Subscriber<Downstream, DownstreamFailure>)
            -> Subscriber<Downstream, DownstreamFailure>,
        preSubscriber: @escaping (inout State)
            -> (Publication<Output, Failure>)
            -> Publication<Downstream, DownstreamFailure>,
        postSubscriber: @escaping (inout State) -> (Demand) -> Demand,
        joinSubscription: @escaping (inout State) -> (Subscription) -> Subscription,
        preSubscription: @escaping (inout State) -> (Request) -> Request,
        postSubscription: @escaping (inout State) -> () -> Void
    ) -> Publisher<Downstream, DownstreamFailure> {
        var state = initialState
        
        let hoist = { (downstream: Subscriber<Downstream, DownstreamFailure>) -> Subscriber<Output, Failure> in
            .init(joinSubscriber(&state)(downstream).dimap(preSubscriber(&state), postSubscriber(&state)))
        }
        
        let lower = { (upstream: Subscription) -> Subscription in
            .init(joinSubscription(&state)(upstream).dimap(preSubscription(&state), postSubscription(&state)))
        }

        return .init(dimap(hoist, lower))
    }
}
