//
//  Statics.swift
//  FreeCombine
//
//  Created by Van Simmons on 4/12/20.
//  Copyright © 2020 ComputeCycles, LLC. All rights reserved.
//

extension Publisher {
    static func output(
        _ subscriber: Subscriber<Output, Failure>,
        _ producer: Producer<Output, Failure>
    ) -> (Demand) -> Void {
        var hasCompleted = false
        return { demand in
            guard demand.quantity > 0 && !hasCompleted else { return }
            var newDemand = demand
            while newDemand.quantity > 0 {
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
        _ subscriber: Subscriber<Output, Failure>,
        _ producer: Producer<Output, Failure>
    ) -> (Control<ControlValue>) -> Void {
        { control in
            producer.finish()
            subscriber.completion(Completion<Failure>.finished)
        }
    }
}
