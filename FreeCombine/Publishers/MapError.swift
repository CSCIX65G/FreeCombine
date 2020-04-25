//
//  MapError.swift
//  FreeCombine
//
//  Created by Van Simmons on 4/25/20.
//  Copyright © 2020 ComputeCycles, LLC. All rights reserved.
//

public extension Publisher {
    func mapError<T: Error>(_ transform: @escaping (Failure) -> T) -> Publisher<Output, T> {
        //public struct Publisher<T, Failure: Error> {
        //    public let call: (Subscriber<T, Failure>) -> Subscription
        //}

        let hoist = { (downstream: Subscriber<Output, T>) -> Subscriber<Output, Failure> in
            downstream.contraMapError(transform)
        }
        
        let lower = { (upstream: Subscription) -> Subscription in
            upstream
        }
        
        return .init(dimap(hoist, lower))
    }
}
