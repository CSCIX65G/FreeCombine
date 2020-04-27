//
//  MapError.swift
//  FreeCombine
//
//  Created by Van Simmons on 4/25/20.
//  Copyright © 2020 ComputeCycles, LLC. All rights reserved.
//

public extension Publisher {
    func mapError<T: Error>(_ transform: @escaping (Failure) -> T) -> Publisher<Output, T> {
        transforming(
            initialState: (),
            joinSubscriber: { _ in identity },
            preSubscriber: { _ in Publication.mapError(transform) },
            postSubscriber: { _ in identity },
            joinSubscription: { _ in identity },
            preSubscription: { _ in identity },
            postSubscription: { _ in { } }
        )
    }
}
