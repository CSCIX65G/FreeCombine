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
        Composer<Output, OutputControl, OutputFailure, T, OutputControl, OutputFailure>(
            liftSubscriber: { (sub) in Subscriber(input: transform >>> sub.input, completion: sub.completion) },
            subscribe: { (_, sub) -> Subscription<OutputControl> in self.receive(subscriber: sub) },
            lowerSubscription: { (_, subscription) in recast(subscription) }
        )
    }
}

//extension Composer {
//    func flatMap<T>(
//        _ transform: @escaping (Output) -> Publisher<T, OutputFailure>
//    ) -> Composer<Output, OutputControl, OutputFailure, T, OutputControl, OutputFailure> {
//        Composer<Output, OutputControl, OutputFailure, T, OutputControl, OutputFailure>(
//            liftSubscriber: { (sub) in
//                Subscriber(
//                    input: transform >>> sub.input,
//                    completion: sub.completion
//                )
//            },
//            subscribe: { (_, sub) -> Subscription<OutputControl> in self.receive(subscriber: sub) },
//            lowerSubscription: { (_, subscription) in recast(subscription) }
//        )
//    }
//}
