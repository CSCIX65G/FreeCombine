//
//  Subscriber.swift
//  FreeCombine
//
//  Created by Van Simmons on 4/12/20.
//  Copyright © 2020 ComputeCycles, LLC. All rights reserved.
//

public extension Publisher {
    func sink(
        receive: @escaping (Publication<Output, Failure>) -> Void
    ) -> Subscription {
        let subscriber = Subscriber<Output, Failure> { receive($0); return .unlimited }
        let subscription = self(subscriber)
        subscription(.demand(.unlimited))
        return subscription
    }

    func assign<Root>(
        to keyPath: ReferenceWritableKeyPath<Root, Output>,
        on object: Root
    ) -> Subscription {
        let subscriber = Subscriber<Output, Failure> { input in
            if case .value(let value) = input {
                object[keyPath: keyPath] = value
            }
            return .unlimited
        }
        let subscription = self(subscriber)
        subscription(.demand(.unlimited))
        return subscription
    }
}
