//
//  Subscriber.swift
//  FreeCombine
//
//  Created by Van Simmons on 4/12/20.
//  Copyright © 2020 ComputeCycles, LLC. All rights reserved.
//

public extension Publisher {
    func sink(
        receivePublication: @escaping (Publication<Output, Failure>) -> Void
    ) -> Subscription {
        let subscription = receive(
            subscriber: Subscriber<Output, Failure> {
                receivePublication($0)
                return .unlimited
            }
        )
        subscription(.demand(.unlimited))
        return subscription
    }

    func assign<Root>(
        to keyPath: ReferenceWritableKeyPath<Root, Output>,
        on object: Root
    ) -> Subscription {
        let subscription = receive(
            subscriber: Subscriber<Output, Failure> { input in
                switch input {
                case .value(let value): object[keyPath: keyPath] = value
                case .failure, .finished: ()
                case .none: return .none
                }
                return .unlimited
            }
        )
        subscription(.demand(.unlimited))
        return subscription
    }
}
