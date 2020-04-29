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
        transformation(
            joinSubscriber: identity,
            transformPublication: Publication.map(transform)
        )
        .transformation(
            joinSubscriber: Subscriber<T?, Failure>.join({ $0 != nil}),
            transformPublication: identity
        )
        .transformation(
            transformPublication: Publication.map(unwrap)
        )
    }
}
