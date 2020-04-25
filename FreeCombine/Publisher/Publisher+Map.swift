//
//  Composition.swift
//  FreeCombine
//
//  Created by Van Simmons on 4/13/20.
//  Copyright © 2020 ComputeCycles, LLC. All rights reserved.
//

// Maps
public extension Publisher {
    func map<T>(_ transform: @escaping (Output) -> T) -> Publisher<T, Failure> {
        //public struct Publisher<T, Failure: Error> {
        //    public let call: (Subscriber<T, Failure>) -> Subscription
        //}

        let hoist = { (subscriber: Subscriber<T, Failure>) -> Subscriber<Output, Failure> in
            subscriber.contraMap(transform)
        }
        
        let lower = { (subscription: Subscription) -> Subscription in
            subscription
        }
        
        return .init(dimap(hoist, lower))
    }
}
