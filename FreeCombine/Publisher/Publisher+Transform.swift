//
//  Publisher+Transform.swift
//  FreeCombine
//
//  Created by Van Simmons on 4/27/20.
//  Copyright © 2020 ComputeCycles, LLC. All rights reserved.
//

public final class Reference<State> {
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
    func transformation<DI, DF>(
        joinSubscriber: @escaping (Subscriber<DI, DF>)
            -> Subscriber<DI, DF> = identity,
        transformPublication: @escaping (Publication<Output, Failure>)
            -> (Publication<DI, DF>),
        joinSubscription: @escaping (Subscription)
            -> Subscription = identity,
        transformRequest: @escaping (Request) -> Request = identity
    ) -> Publisher<DI, DF> {

        let hoist = { (downstream: Subscriber<DI, DF>) -> Subscriber<Output, Failure> in
            .init(downstream.contraFlatMap(joinSubscriber, transformPublication))
        }
        
        let lower = { (mySubscription: Subscription) -> Subscription in
            .init(mySubscription.contraFlatMap(joinSubscription, transformRequest))
        }

        return .init(dimap(hoist, lower))
    }
}
