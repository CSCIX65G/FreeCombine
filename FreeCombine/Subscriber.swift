//
//  Subscriber.swift
//  FreeCombine
//
//  Created by Van Simmons on 4/12/20.
//  Copyright © 2020 ComputeCycles, LLC. All rights reserved.
//

typealias Subscriber<Input, InputFailure: Error> =
    PubSub<Input, Never, InputFailure, Never, Never, Never>

extension PubSub {
    func sink(
        receiveCompletion: @escaping ((Completion<OutputFailure>) -> Void) = { _ in },
        receiveValue: @escaping ((Output) -> Void)
    ) -> Subscription<OutputControl> {
        let subscription = receive(
            subscriber: Subscribing<Output, OutputFailure, OutputControl>(
                input: { input in receiveValue(input); return .unlimited },
                completion: receiveCompletion
            )
        )
        subscription.request(.unlimited)
        return subscription
    }
}
