//
//  Publisher+Transform.swift
//  FreeCombine
//
//  Created by Van Simmons on 4/27/20.
//  Copyright © 2020 ComputeCycles, LLC. All rights reserved.
//

public final class StateRef<State> {
    var state: State
    init(_ state: State) {
        self.state = state
    }
    
    func save(_ state: State) -> State {
        self.state = state
        return state
    }
}

extension Publisher {
    func transformation<Downstream, DownstreamFailure>(
        joinSubscriber: @escaping (Subscriber<Downstream, DownstreamFailure>)
            -> Subscriber<Downstream, DownstreamFailure> = identity,
        transformPublication: @escaping (Publication<Output, Failure>)
            -> (Publication<Downstream, DownstreamFailure>),
        joinSubscription: @escaping (Subscription)
            -> Subscription = identity,
        transformRequest: @escaping (Request)
            -> Request = identity
    ) -> Publisher<Downstream, DownstreamFailure> {
        
        let hoist = { (downstream: Subscriber<Downstream, DownstreamFailure>) -> Subscriber<Output, Failure> in
            .init(downstream.contraFlatMap(joinSubscriber, transformPublication))
        }
        
        let lower = { (upstream: Subscription) -> Subscription in
            .init(upstream.contraFlatMap(joinSubscription, transformRequest))
        }

        return .init(dimap(hoist, lower))
    }
}
