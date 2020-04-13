//
//  Statics.swift
//  FreeCombine
//
//  Created by Van Simmons on 4/12/20.
//  Copyright © 2020 ComputeCycles, LLC. All rights reserved.
//

extension PubSub {
    static func output<Output, OutputFailure: Error>(
        _ subscriber: Subscribing<Output, OutputFailure, Never>,
        _ next: @escaping (Demand) -> Supply<Output, OutputFailure>,
        _ demand: Demand
    ) -> Void {
        guard demand.intValue > 0 else { return }
        var newDemand = demand
        while newDemand.intValue > 0 {
            let supply = next(newDemand)
            switch supply {
            case .none: return
            case .some(let value): newDemand = subscriber.input(value)
            case .failure(let failure): subscriber.completion(.error(failure)); return
            case .done: subscriber.completion(.finished); return
            }
        }
    }
    
    static func finished(
        _ subscriber: Subscribing<Output, OutputFailure, OutputControl>,
        _ control: Control<OutputControl>
    ) -> Void {
        subscriber.completion(Completion<OutputFailure>.finished)
    }
}
