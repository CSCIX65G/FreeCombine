//
//  Statics.swift
//  FreeCombine
//
//  Created by Van Simmons on 4/12/20.
//  Copyright © 2020 ComputeCycles, LLC. All rights reserved.
//

extension Publisher {
    static func finished(
        _ producer: Producer<Output, OutputFailure>
    ) -> (Subscriber<Output, OutputFailure>) -> (Control<OutputControl>) -> Void {
        { subscriber in
            { control in
                switch control {
                case .finish:
                    producer.finish()
                    subscriber.completion(Completion<OutputFailure>.finished)
                default: ()
                }
            }
        }
    }

    static func output(
        _ producer: Producer<Output, OutputFailure>
    ) -> (Subscriber<Output, OutputFailure>) -> (Demand) -> Void {
        { subscriber in
            var hasCompleted = false
            return { demand in
                guard demand.quantity > 0 && !hasCompleted else { return }
                var newDemand = demand
                while newDemand.quantity > 0 {
                    let supply = producer.produce(newDemand)
                    switch supply {
                    case .none:
                        return
                    case .some(let value):
                        newDemand = subscriber.input(value)
                    case .done:
                        subscriber.completion(.finished)
                        hasCompleted = true
                        return
                    }
                }
            }
        }
    }
}
