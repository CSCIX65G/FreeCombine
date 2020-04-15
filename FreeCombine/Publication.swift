//
//  Publication.swift
//  FreeCombine
//
//  Created by Van Simmons on 4/15/20.
//  Copyright © 2020 ComputeCycles, LLC. All rights reserved.
//

struct Publication<Output, ControlValue, Failure: Error> {
    typealias RequestGenerator = (Subscriber<Output, Failure>) -> (Demand) -> Void
    typealias ControlGenerator = (Subscriber<Output, Failure>) -> (Control<ControlValue>) -> Void
    
    var request: RequestGenerator
    var control: ControlGenerator
    
    init(
        _ producer: Producer<Output, Failure>,
        _ request: RequestGenerator? = nil,
        _ control: ControlGenerator? = nil
    ) {
        self.request = request ?? Self.output(producer)
        self.control = control ?? Self.finished(producer)
    }
}
