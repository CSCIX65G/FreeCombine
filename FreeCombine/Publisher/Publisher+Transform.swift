//
//  Publisher+Transform.swift
//  FreeCombine
//
//  Created by Van Simmons on 4/27/20.
//  Copyright © 2020 ComputeCycles, LLC. All rights reserved.
//

class StateRef<State> {
    var state: State
    init(_ state: State) {
        self.state = state
    }
}

extension Publisher {
    func transforming<State, Downstream, DownstreamFailure>(
        initialState: State,
        joinSubscriber: @escaping (StateRef<State>)
            -> (Subscriber<Downstream, DownstreamFailure>)
            -> Subscriber<Downstream, DownstreamFailure> = { _ in identity },
        preSubscriber: @escaping (StateRef<State>)
            -> (Publication<Output, Failure>)
            -> Publication<Downstream, DownstreamFailure>,
        postSubscriber: @escaping (StateRef<State>) -> (Demand) -> Demand  = { _ in identity },
        joinSubscription: @escaping (StateRef<State>) -> (Subscription) -> Subscription = { _ in identity },
        preSubscription: @escaping (StateRef<State>) -> (Request) -> Request  = { _ in identity },
        postSubscription: @escaping (StateRef<State>) -> () -> Void = { _ in { } }
    ) -> Publisher<Downstream, DownstreamFailure> {
        let state = StateRef(initialState)
        
        let hoist = { (downstream: Subscriber<Downstream, DownstreamFailure>) -> Subscriber<Output, Failure> in
            .init(joinSubscriber(state)(downstream).dimap(preSubscriber(state), postSubscriber(state)))
        }
        
        let lower = { (upstream: Subscription) -> Subscription in
            .init(joinSubscription(state)(upstream).dimap(preSubscription(state), postSubscription(state)))
        }

        return .init(dimap(hoist, lower))
    }
}
