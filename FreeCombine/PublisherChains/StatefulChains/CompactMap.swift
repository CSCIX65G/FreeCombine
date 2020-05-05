//
//  CompactMap.swift
//  FreeCombine
//
//  Created by Van Simmons on 4/25/20.
//  Copyright © 2020 ComputeCycles, LLC. All rights reserved.
//

public extension Publisher {
    func compactMap<T>(
        _ transform: @escaping (Output) -> T?
    ) -> Publisher<T, Failure> {
        transformation(transformSupply: Supply.map(transform))
        .transformation(
            joinSubscriber: Subscriber<T?, Failure>.filterJoin({ $0 != nil}),
            transformSupply: identity
        )
        .transformation(transformSupply: Supply.map(unwrap))
    }
}
