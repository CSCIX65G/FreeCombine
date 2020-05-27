//
//  Composition.swift
//  FreeCombine
//
//  Created by Van Simmons on 4/13/20.
//  Copyright © 2020 ComputeCycles, LLC. All rights reserved.
//

// Given:
//   1) Self                   = Publisher<Output, Failure>
//                             = (Subscriber<Output, Failure>) -> Subscription
//                             = ((Supply<Output, Failure>) -> Demand) -> (Demand) -> Void
//   2) Subscriber<T, Failure> = (Supply<T, Failure>) -> Demand
//   3) (Output) -> T
//
// Can we get to:
//
// Desired: Publisher<T, Failure> = (Subscriber<T, Failure>) -> Subscription
//                                = ((Supply<T, Failure>) -> Demand) -> (Demand) -> Void
//
// So if we had:
//   1) (Subscriber<T, Failure>) -> Subscriber<Output, Failure>
//                 = ((Supply<T, Failure>) -> Demand) -> (Supply<Output, Failure>) -> Demand
//   2) (Subscription) -> Subscription
//                 = ((Demand) -> Void) -> (Demand) -> Void
//
// we could `dimap` such functions onto self and get the desired output
//
// Can we derive two such functions from what we have? Yes! with `contraFlatMap`
//
// The general pattern is:
// Subscriber<DownStream, Failure>) -> Subscriber<Upstream, Failure> aka `hoist`
// Subscriber<Upstream, Failure> -> Subscription ("Upstream")
// Subscription ("Upstream") -> Subscription ("Downstream")  aka `lower`
//
// Compose those three together to get Subscriber<Downstream, Failure> -> Subscription ("Downstream")

public extension Publisher {
    func map<T>(
        _ transform: @escaping (Output) -> T
    ) -> Publisher<T, Failure> {

        let hoist = { (downstream: Subscriber<T, Failure>) -> Subscriber<Output, Failure> in
            .init(downstream.contraFlatMap(identity, Supply.map(transform)))
        }
        // => contraMap
        
        let lower = { (mySubscription: Subscription) -> Subscription in
            .init(mySubscription.contraFlatMap(identity, identity))
        }
        // => identity

        return .init(dimap(hoist, lower))

    }
}
