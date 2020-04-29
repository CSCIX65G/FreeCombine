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
        transformRequest: @escaping (Request) -> Request = identity
    ) -> Publisher<Downstream, DownstreamFailure> {
        typealias DownstreamSubscriber = Subscriber<Downstream, DownstreamFailure>
        typealias MySubscriber = Subscriber<Output, Failure>
        typealias DownstreamSubscription = Subscription
        typealias MySubscription = Subscription
        
        let hoist = { (downstream: DownstreamSubscriber) -> MySubscriber in
            .init(downstream.contraFlatMap(joinSubscriber, transformPublication))
        }
        
        let lower = { (mySubscription: MySubscription) -> DownstreamSubscription in
            .init(mySubscription.contraMap(transformRequest))
        }

        return .init(dimap(hoist, lower))
    }
}
