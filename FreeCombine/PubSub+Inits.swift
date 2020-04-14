//
//  Subscriber+Inits.swift
//  FreeCombine
//
//  Created by Van Simmons on 4/13/20.
//  Copyright © 2020 ComputeCycles, LLC. All rights reserved.
//

//extension Composer {
//    init(
//        input: @escaping ((Output) -> Demand) -> (Input) -> Demand,
//        completion: @escaping ((Completion<OutputFailure>) -> Void) -> (Completion<InputFailure>) -> Void,
//        subscribe: @escaping (Subscriber<Output, OutputFailure>) -> Subscription<OutputControl>,
//        request: @escaping ((Demand) -> Void) -> (Demand) -> Void,
//        control: @escaping ((Control<OutputControl>) -> Void) -> (Control<InputControl>) -> Void
//    ) {
//        self.composition = Self.Composition.publisherSubscriber(
//            recast(Subscriber<Output, OutputFailure>.transform(input, completion)),
//            recast(subscribe),
//            recast(Subscription<OutputControl>.transform(request, control))
//        )
//    }
//}
