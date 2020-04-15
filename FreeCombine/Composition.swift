//
//  Composition.swift
//  FreeCombine
//
//  Created by Van Simmons on 4/13/20.
//  Copyright © 2020 ComputeCycles, LLC. All rights reserved.
//

extension Publication {
    func map<T>(
        _ transform: @escaping (Output) -> T
    ) -> Publication<Output, OutputControl, OutputFailure, T, OutputControl, OutputFailure> {
        Publication<Output, OutputControl, OutputFailure, T, OutputControl, OutputFailure>(
            hoist: recast(Subscriber<Output, OutputFailure>.map(transform, identity)),
            subscribe: receive,
            lower: identity
        )
    }

    func mapError<T: Error>(
        _ transform: @escaping (OutputFailure) -> T
    ) -> Publication<Output, OutputControl, OutputFailure, Output, OutputControl, T> {
        Publication<Output, OutputControl, OutputFailure, Output, OutputControl, T>(
            hoist: recast(Subscriber<Output, OutputFailure>.mapError(transform)),
            subscribe: receive,
            lower: identity
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
