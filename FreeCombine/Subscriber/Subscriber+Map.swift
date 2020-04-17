//
//  Subscriber+Transforms.swift
//  FreeCombine
//
//  Created by Van Simmons on 4/14/20.
//  Copyright © 2020 ComputeCycles, LLC. All rights reserved.
//
extension Subscriber {
    static func map(
        _ transform: @escaping (Demand) -> Demand
    ) -> (Self) -> Subscriber<Input, Failure> {
        { subscriber in
            Subscriber<Input, Failure>(
                input: subscriber.input >>> transform ,
                completion: subscriber.completion
            )
        }
    }
}

// ContraMaps
// dInput: (A) -> B
// uInput: (C) -> B
// to turn a dInput into an uInput we need:
// transform: (C) -> A then:
// transform >>> dInput is (C) -> B
// In this case B and D are both of type Demand, but they may have different values
// inputTransform is dPre, demandTransform is dPost
extension Subscriber {
    static func contraMap<UpstreamInput, UpstreamFailure: Error>(
        _ inputTransform: @escaping (UpstreamInput) -> Input,
        _ completionTransform: @escaping (UpstreamFailure) -> Failure
    ) -> (Self) -> Subscriber<UpstreamInput, UpstreamFailure> {
        { subscriber in
            subscriber
                |> Subscriber<Input, Failure>.contraMap(inputTransform)
                >>> Subscriber<UpstreamInput, Failure>.contraMapError(completionTransform)
        }
    }
}


extension Subscriber {
    static func contraMap<UpstreamInput>(
        _ transform: @escaping (UpstreamInput) -> Input
    ) -> (Self) -> Subscriber<UpstreamInput, Failure> {
        { subscriber in
            Subscriber<UpstreamInput, Failure>(
                input: transform >>> subscriber.input,
                completion: subscriber.completion
            )
        }
    }
}

extension Completion {
    static func map<T: Error>(
        _ transform: @escaping (Failure) -> T
    ) -> (Self) -> Completion<T> {
        { completion in
            switch completion {
            case .finished: return .finished
            case .error(let e): return .error(transform(e))
            }
        }
    }
}


// We don't need the pre/post transform distinction here
// because the functions being mapped are both -> Void
extension Subscriber {
    static func contraMapError<UpstreamFailure: Error>(
        _ transform: @escaping (UpstreamFailure) -> Failure
    )  -> (Self) -> Subscriber<Input, UpstreamFailure> {
        { subscriber in
            Subscriber<Input, UpstreamFailure>(
                input: subscriber.input,
                completion: (transform |> Completion.map) >>> subscriber.completion
            )
        }
    }
}
