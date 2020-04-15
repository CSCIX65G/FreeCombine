//
//  Subscriber+Transforms.swift
//  FreeCombine
//
//  Created by Van Simmons on 4/14/20.
//  Copyright © 2020 ComputeCycles, LLC. All rights reserved.
//

// Maps
extension Subscriber {
    static func map<DownstreamInput>(
        _ transform: @escaping (Input) -> DownstreamInput
    ) -> (Self) -> Subscriber<DownstreamInput, Failure> {
        { subscriber in
            Subscriber<DownstreamInput, Failure>(
                input: recast(transform) >>> subscriber.input,
                completion: subscriber.completion
            )
        }
    }

    static func contraMap(
        _ transform: @escaping (Demand) -> Demand
    ) -> (Self) -> Subscriber<Input, Failure> {
        { subscriber in
            Subscriber<Input, Failure>(
                input: subscriber.input >>> transform,
                completion: subscriber.completion
            )
        }
    }
    
    static func mapError<DownstreamFailure: Error>(
        _ transform: @escaping (Failure) -> DownstreamFailure
    ) -> (Self) -> Subscriber<Input, DownstreamFailure> {
        { subscription in
            Subscriber<Input, DownstreamFailure>(
                input: subscription.input,
                completion: recast(transform) >>> subscription.completion
            )
        }
    }
}
