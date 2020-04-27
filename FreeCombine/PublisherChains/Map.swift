//
//  Composition.swift
//  FreeCombine
//
//  Created by Van Simmons on 4/13/20.
//  Copyright © 2020 ComputeCycles, LLC. All rights reserved.
//

public extension Publisher {
    func map<T>(_ transform: @escaping (Output) -> T) -> Publisher<T, Failure> {
        transforming(
            initialState: (),
            joinSubscriber: { _ in identity },
            preSubscriber: { _ in Publication.map(transform) },
            postSubscriber: { _ in identity },
            joinSubscription: { _ in identity },
            preSubscription: { _ in identity },
            postSubscription: { _ in { } }
        )
    }
}
