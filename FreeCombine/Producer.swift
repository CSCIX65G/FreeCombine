//
//  Statics.swift
//  FreeCombine
//
//  Created by Van Simmons on 4/12/20.
//  Copyright © 2020 ComputeCycles, LLC. All rights reserved.
//

extension Composer {
    static func output(
        _ subscriber: Subscriber<Output, OutputFailure, Never>,
        _ producer: Producer<Output, OutputFailure>,
        _ demand: Demand
    ) -> Void {
        guard demand.intValue > 0 else { return }
        var newDemand = demand
        while newDemand.intValue > 0 {
            let supply = producer.produce(newDemand)
            switch supply {
            case .none: return
            case .some(let value): newDemand = subscriber.input(value)
            case .failure(let failure): subscriber.completion(.error(failure)); return
            case .done: subscriber.completion(.finished); return
            }
        }
    }
    
    static func finished(
        _ subscriber: Subscriber<Output, OutputFailure, OutputControl>,
        _ producer: Producer<Output, OutputFailure>,
        _ control: Control<OutputControl>
    ) -> Void {
        producer.finish()
        subscriber.completion(Completion<OutputFailure>.finished)
    }
}
