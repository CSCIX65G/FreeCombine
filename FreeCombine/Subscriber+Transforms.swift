//
//  Subscriber+Transforms.swift
//  FreeCombine
//
//  Created by Van Simmons on 4/14/20.
//  Copyright © 2020 ComputeCycles, LLC. All rights reserved.
//

// ContraMaps
// dInput: (A) -> B
// uInput: (C) -> D
// to turn a dinput into an uinput we need:
// dPre: (C) -> A and dPost: (B) -> D, then:
// dPre >>> dInput >>> dPost is (C) -> D
// In this case B and D are both of type Demand, but they may have different values
// inputTransform is dPre, demandTransform is dPost
extension Subscriber {
    static func contraMap<UpstreamInput>(
        _ preTransform: @escaping (UpstreamInput) -> Input,
        _ postTransform: @escaping (Demand) -> Demand
    ) -> (Self) -> Subscriber<UpstreamInput, Failure> {
        { subscriber in
            Subscriber<UpstreamInput, Failure>(
                input: preTransform >>> subscriber.input >>> postTransform,
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
