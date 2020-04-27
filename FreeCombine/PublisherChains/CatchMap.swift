//
//  TryMap.swift
//  FreeCombine
//
//  Created by Van Simmons on 4/25/20.
//  Copyright © 2020 ComputeCycles, LLC. All rights reserved.
//

// TODO: Implement tryMap
public extension Publisher {
    func catchMap<T>(
        _ transform: @escaping (Output) throws -> T
    ) -> Publisher<Result<T, Error>, Error> {
        transforming(
            initialState: (),
            joinSubscriber: { _ in identity },
            preSubscriber: { _ in Publication.catchMap(transform) },
            postSubscriber: { _ in identity },
            joinSubscription: { _ in identity },
            preSubscription: { _ in identity },
            postSubscription: { _ in { } }
        )
    }
}
