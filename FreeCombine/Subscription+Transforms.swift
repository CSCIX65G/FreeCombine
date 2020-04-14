//
//  Subscription+Transforms.swift
//  FreeCombine
//
//  Created by Van Simmons on 4/14/20.
//  Copyright © 2020 ComputeCycles, LLC. All rights reserved.
//

extension Subscription {
    static func map(
        _ transform: @escaping (Demand) -> Demand
    ) -> (Subscription<ControlValue>) -> Subscription<ControlValue> {
        { subscription in
            Subscription<ControlValue>(
                request: transform >>> subscription.request,
                control: subscription.control
            )
        }
    }

    static func mapControl<UpstreamControlValue>(
        _ transform: @escaping (ControlValue) -> UpstreamControlValue
    ) -> (Subscription<ControlValue>) -> Subscription<UpstreamControlValue> {
        { subscription in
            Subscription<UpstreamControlValue>(
                request: subscription.request,
                control: recast(transform) >>> subscription.control
            )
        }
    }
}
