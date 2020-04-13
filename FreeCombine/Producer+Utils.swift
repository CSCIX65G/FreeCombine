//
//  Statics.swift
//  FreeCombine
//
//  Created by Van Simmons on 4/12/20.
//  Copyright © 2020 ComputeCycles, LLC. All rights reserved.
//

extension Composer {
    static func output(
        _ subscriber: Subscriber<Output, OutputFailure, OutputControl>,
        _ producer: Producer<Output, OutputFailure>
    ) -> (Demand) -> Void {
        var hasCompleted = false
        return { demand in
            guard demand.intValue > 0 && !hasCompleted else { return }
            var newDemand = demand
            while newDemand.intValue > 0 {
                let supply = producer.produce(newDemand)
                switch supply {
                case .none: return
                case .some(let value): newDemand = subscriber.input(value)
                case .done: subscriber.completion(.finished); hasCompleted = true; return
                }
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
