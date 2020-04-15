//
//  Publication.swift
//  FreeCombine
//
//  Created by Van Simmons on 4/15/20.
//  Copyright © 2020 ComputeCycles, LLC. All rights reserved.
//

struct Publication<Output, ControlValue, Failure: Error> {
    // Types for creating a Subscription from a Subscriber
    typealias RequestGenerator = (Subscriber<Output, Failure>) -> (Demand) -> Void
    typealias ControlGenerator = (Subscriber<Output, Failure>) -> (Control<ControlValue>) -> Void
    
    var request: RequestGenerator
    var control: ControlGenerator
    
    init(
        _ producer: Producer<Output, Failure>,
        _ request: RequestGenerator? = nil,
        _ control: ControlGenerator? = nil
    ) {
        self.request = request ?? Self.output(producer)    // synchronously connect to output
        self.control = control ?? Self.finished(producer)  // ignore control messages only handle finish
    }
}

extension Publication {
    func receive(subscriber: Subscriber<Output, Failure>) -> Subscription<ControlValue> {
        .init(request: subscriber |> request, control: subscriber |> control)
    }
}

extension Publication {
    var publisher: Publisher<Output, ControlValue, Failure,Output, ControlValue, Failure> {
        Publisher(hoist: identity, convert: receive, lower: identity)
    }
}
