//
//  Subscription+Transforms.swift
//  FreeCombine
//
//  Created by Van Simmons on 4/14/20.
//  Copyright © 2020 ComputeCycles, LLC. All rights reserved.
//

extension Subscription {
    // turn the requested downstream command into the requested upstream demand
    static func contraMap(
        _ transform: @escaping (Demand) -> Demand  // (Downstream) -> (Upstream)
    ) -> (Subscription<ControlValue>) -> Subscription<ControlValue> {  // lower Upstream -> Downstream
        { subscription in
            Subscription<ControlValue>(
                request: transform >>> subscription.request,
                control: subscription.control
            )
        }
    }
}

extension Control {
    static func map<T>(
        _ transform: @escaping (Value) -> T
    ) -> (Self) -> Control<T> {
        { control in
            switch control {
            case .finish: return .finish
            case .control(let c): return .control(transform(c))
            }
        }
    }
}

extension Subscription {
    // turn the downstream control command into the upstream upstream control command
    static func contraMapControl<DownstreamControlValue>(
        _ transform: @escaping (DownstreamControlValue) -> ControlValue   // (Downstream) -> Upstream
    ) -> (Subscription<ControlValue>) -> Subscription<DownstreamControlValue> { // lower Upstream -> Downstream
        { subscription in
            Subscription<DownstreamControlValue>(
                request: subscription.request,
                control: (transform |> Control.map) >>> subscription.control
            )
        }
    }
}
