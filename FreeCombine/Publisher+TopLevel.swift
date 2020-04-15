//
//  Publication.swift
//  FreeCombine
//
//  Created by Van Simmons on 4/15/20.
//  Copyright © 2020 ComputeCycles, LLC. All rights reserved.
//

public extension Publisher
    where Input == Output, InputFailure == OutputFailure, InputControl == OutputControl {
    // Types for creating a Subscription from a Subscriber
    typealias RequestGenerator = (Subscriber<Output, OutputFailure>) -> (Demand) -> Void
    typealias ControlGenerator = (Subscriber<Output, OutputFailure>) -> (Control<OutputControl>) -> Void
    
    init(
        _ producer: Producer<Output, OutputFailure>,
        _ request: RequestGenerator? = nil,
        _ control: ControlGenerator? = nil
    ) {
        let request = request ?? Self.output(producer)    // synchronously connect to output
        let control = control ?? Self.finished(producer)  // ignore control messages only handle finish

        self.hoist = identity
        self.convert = { subscriber in
            UpstreamSubscription(
                request: subscriber |> request,
                control: subscriber |> recast(control)
            )
        }
        self.lower = identity
    }
}
