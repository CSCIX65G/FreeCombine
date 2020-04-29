//
//  Reduce.swift
//  FreeCombine
//
//  Created by Van Simmons on 4/25/20.
//  Copyright © 2020 ComputeCycles, LLC. All rights reserved.
//

public extension Publisher {
    func reduce(
        _ initial: Output,
        _ reduce: @escaping (Output, Output) -> Output
    ) -> Publisher<Output, Failure> {
        transformation(
            joinSubscriber: Subscriber<Output, Failure>.join(initial, reduce),
            transformPublication: identity,
            transformRequest: {
                switch $0 {
                case .cancel: return .cancel
                case .demand: return .demand(.unlimited)
                }
            }
        )
    }
}
