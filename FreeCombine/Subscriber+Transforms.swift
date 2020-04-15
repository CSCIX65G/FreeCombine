//
//  Subscriber+Transforms.swift
//  FreeCombine
//
//  Created by Van Simmons on 4/14/20.
//  Copyright © 2020 ComputeCycles, LLC. All rights reserved.
//

// Maps
extension Subscriber {
    static func map<UpstreamInput>(
        _ transform: @escaping (Input) -> UpstreamInput
    ) -> (Self) -> Subscriber<UpstreamInput, Failure> {
        { subscriber in
            recast(Subscriber(
                input: transform >>> recast(subscriber.input),
                completion: subscriber.completion
            ))
        }
    }

    static func contraMap(
        _ transform: @escaping (Demand) -> Demand
    ) -> (Self) -> Subscriber<Input, Failure> {
        { subscriber in
            recast(Subscriber(
                input: subscriber.input >>> transform,
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
