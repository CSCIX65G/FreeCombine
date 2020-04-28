//
//  Publisher+Transform.swift
//  FreeCombine
//
//  Created by Van Simmons on 4/27/20.
//  Copyright © 2020 ComputeCycles, LLC. All rights reserved.
//

extension Publisher {
    func mapTransformation<Downstream, DownstreamFailure>(
        preSubscriber: @escaping (Publication<Output, Failure>)  -> Publication<Downstream, DownstreamFailure>,
        postSubscriber: @escaping (Demand) -> Demand  = identity,
        preSubscription: @escaping (Request) -> Request  = identity ,
        postSubscription: @escaping () -> Void = { }
    ) -> Publisher<Downstream, DownstreamFailure> {
        
        let hoist = { (downstream: Subscriber<Downstream, DownstreamFailure>) -> Subscriber<Output, Failure> in
            .init(downstream.dimap(preSubscriber, postSubscriber))
        }
        
        let lower = { (upstream: Subscription) -> Subscription in
            .init(upstream.dimap(preSubscription, postSubscription))
        }

        return .init(dimap(hoist, lower))
    }
    
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

    func flatMapTransformation<State, Downstream, DownstreamFailure>(
        initialState: State,
        joinSubscriber: @escaping (StateRef<State>)
            -> (Subscriber<Downstream, DownstreamFailure>)
            -> Subscriber<Downstream, DownstreamFailure> = { _ in identity },
        transformPublication: @escaping (StateRef<State>)
            -> (Publication<Output, Failure>)
            -> (Publication<Downstream, DownstreamFailure>),
        joinSubscription: @escaping (StateRef<State>)
            -> (Subscription)
            -> Subscription = { _ in identity },
        transformRequest: @escaping (StateRef<State>)
            -> (Request)
            -> Request = { _ in identity }
    ) -> Publisher<Downstream, DownstreamFailure> {
        let state = StateRef(initialState)
        
        let hoist = { (downstream: Subscriber<Downstream, DownstreamFailure>) -> Subscriber<Output, Failure> in
            .init(downstream.contraFlatMap(joinSubscriber(state), transformPublication(state)))
        }
        
        let lower = { (upstream: Subscription) -> Subscription in
            .init(upstream.contraFlatMap(joinSubscription(state), transformRequest(state)))
        }

        return .init(dimap(hoist, lower))
    }
}
