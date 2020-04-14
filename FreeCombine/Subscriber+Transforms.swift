//
//  Subscriber+Transforms.swift
//  FreeCombine
//
//  Created by Van Simmons on 4/14/20.
//  Copyright © 2020 ComputeCycles, LLC. All rights reserved.
//

// Production
extension Subscriber {
    static func subscription<ControlValue>(
        for producer: Producer<Input, Failure>
    ) -> (Self) -> Subscription<ControlValue> {
        { subscriber in
            Subscription<ControlValue> (
                request: Publisher<Input, Failure>.output(subscriber, producer),
                control: recast(Publisher<Input, Failure>.finished(subscriber, recast(producer)))
            )
        }
    }
}

// Maps
extension Subscriber {
    static func map<UpstreamInput>(
        _ transform: @escaping (Input) -> UpstreamInput,
        _ demand: @escaping (Demand) -> Demand
    ) -> (Self) -> Subscriber<UpstreamInput, Failure> {
        { subscriber in
            recast(Subscriber(
                input: transform >>> recast(subscriber.input) >>> demand,
                completion: subscriber.completion
            ))
        }
    }

    static func mapError<UpstreamFailure: Error>(
        _ transform: @escaping (Failure) -> UpstreamFailure
    ) -> (Self) -> Subscriber<Input, UpstreamFailure> {
        { subscription in
            recast(Subscriber(
                input: subscription.input,
                completion: recast(transform) >>> subscription.completion
            ))
        }
    }
}
