//
//  Composition.swift
//  FreeCombine
//
//  Created by Van Simmons on 4/13/20.
//  Copyright © 2020 ComputeCycles, LLC. All rights reserved.
//

public extension Publisher {
    func map<T>(_ transform: @escaping (Output) -> T) -> Publisher<T, Failure> {
        //public struct Publisher<T, Failure: Error> {
        //    public let call: (Subscriber<T, Failure>) -> Subscription
        //}

        let hoist = { (downstream: Subscriber<T, Failure>) -> Subscriber<Output, Failure> in
            downstream.contraMap(transform)
        }
        
        let lower = { (upstream: Subscription) -> Subscription in
            upstream
        }
        
        return .init(dimap(hoist, lower))
    }
}
