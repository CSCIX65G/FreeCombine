//
//  Composition.swift
//  FreeCombine
//
//  Created by Van Simmons on 4/13/20.
//  Copyright © 2020 ComputeCycles, LLC. All rights reserved.
//

extension Subscription {
    typealias RequestTransform =
        ((Demand) -> Void) -> (Demand) -> Void
    typealias ControlTransform<New> =
        ((Control<ControlValue>) -> Void) -> (Control<New>) -> Void
    
    static func map<UpstreamControlValue>(
        _ requestTransform: @escaping RequestTransform,
        _ controlTransform: @escaping ControlTransform<UpstreamControlValue>
    ) -> (Subscription<ControlValue>) -> Subscription<UpstreamControlValue> {
        { subscription in
            Subscription<UpstreamControlValue>(
                request: subscription.request |> requestTransform,
                control: subscription.control |> controlTransform
            )
        }
    }
}

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
}

extension Composer {
    func map<T>(
        _ transform: @escaping (Output) -> T
    ) -> Composer<Output, OutputControl, OutputFailure, T, OutputControl, OutputFailure> {
        typealias C = Composer<Output, OutputControl, OutputFailure, T, OutputControl, OutputFailure>
        return C.init(
            composition: recast(C.Composition.publisherSubscriber(
                recast(Subscriber<Output, OutputFailure>.map(transform, identity)),
                receive,
                recast >>> identity
            ))
        )
    }
}

//extension Composer {
//    func flatMap<T>(
//        _ transform: @escaping (Output) -> Publisher<T, OutputFailure>
//    ) -> Composer<Output, OutputControl, OutputFailure, T, OutputControl, OutputFailure> {
//        .init(
//            composition: .publisherSubscriber(
//                liftSubscriber: { (sub) in
//                    Subscriber(
//                        input: transform >>> sub.input,
//                        completion: sub.completion
//                    )
//                },
//                subscribe: receive,
//                lowerSubscription: identity
//            )
//        )
//    }
//}
