//
//  Subscriber.swift
//  FreeCombine
//
//  Created by Van Simmons on 4/12/20.
//  Copyright © 2020 ComputeCycles, LLC. All rights reserved.
//

public extension Publisher {
    func sink(
        receiveCompletion: @escaping ((Completion<OutputFailure>) -> Void) = { _ in },
        receiveValue: @escaping ((Output) -> Void)
    ) -> Subscription<OutputControl> {
        let subscription = receive(
            subscriber: Subscriber<Output, OutputFailure>(
                input: { input in receiveValue(input); return .unlimited },
                completion: receiveCompletion
            )
        )
        subscription.request(.unlimited)
        return subscription
    }

    func assign<Root>(
        to keyPath: ReferenceWritableKeyPath<Root, Output>,
        on object: Root
    ) -> Subscription<OutputControl> {
        let subscription = receive(
            subscriber: Subscriber<Output, OutputFailure>(
                input: { input in object[keyPath: keyPath] = input; return .unlimited },
                completion: { _ in }
            )
        )
        subscription.request(.unlimited)
        return subscription
    }
}
