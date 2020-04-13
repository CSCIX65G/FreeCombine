//
//  Subscriber.swift
//  FreeCombine
//
//  Created by Van Simmons on 4/12/20.
//  Copyright © 2020 ComputeCycles, LLC. All rights reserved.
//

extension Composer {
    func sink(
        receiveCompletion: @escaping ((Completion<OutputFailure>) -> Void) = { _ in },
        receiveValue: @escaping ((Output) -> Void)
    ) -> Subscription<OutputControl> {
        let subscription = receive(
            subscriber: Subscriber<Output, OutputFailure, OutputControl>(
                input: { input in receiveValue(input); return .unlimited },
                completion: receiveCompletion
            )
        )
        subscription.request(.unlimited)
        return subscription
    }
}
