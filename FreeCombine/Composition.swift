//
//  Composition.swift
//  FreeCombine
//
//  Created by Van Simmons on 4/13/20.
//  Copyright © 2020 ComputeCycles, LLC. All rights reserved.
//

extension Composer {
    func map<T>(
        _ transform: @escaping (Output) -> T
    ) -> Composer<Output, OutputControl, OutputFailure, T, OutputControl, OutputFailure> {
        .init(
            composition: .publisherSubscriber(
                recast(Subscriber<Output, OutputFailure>.map(transform, identity)),
                receive,
                recast >>> identity
            )
        )
    }

    func mapError<T: Error>(
        _ transform: @escaping (OutputFailure) -> T
    ) -> Composer<Output, OutputControl, OutputFailure, Output, OutputControl, T> {
        typealias C = Composer<Output, OutputControl, OutputFailure, Output, OutputControl, T>
        return C(
            composition: C.Composition.publisherSubscriber(
                recast(Subscriber<Output, OutputFailure>.mapError(transform)),
                receive,
                recast >>> identity
            )
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
