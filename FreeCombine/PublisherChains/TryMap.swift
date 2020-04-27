//
//  TryMap.swift
//  FreeCombine
//
//  Created by Van Simmons on 4/26/20.
//  Copyright © 2020 ComputeCycles, LLC. All rights reserved.
//

public extension Publisher {
    func tryMap<T>(_ transform: @escaping (Output) throws -> T) -> Publisher<T, Error> {
        transforming(
            initialState: (),
            joinSubscriber: { _ in identity },
            preSubscriber: { _ in Publication.tryMap(transform) },
            postSubscriber: { _ in identity },
            joinSubscription: { _ in identity },
            preSubscription: { _ in identity },
            postSubscription: { _ in { } }
        )
    }
}
