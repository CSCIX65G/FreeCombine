//
//  Composition.swift
//  FreeCombine
//
//  Created by Van Simmons on 4/13/20.
//  Copyright © 2020 ComputeCycles, LLC. All rights reserved.
//

// Maps
public extension Publisher {
    typealias MapPublisher<T> =
        Publisher<Output, OutputControl, OutputFailure, T, OutputControl, OutputFailure>
    
    func map<T>(
        _ transform: @escaping (Output) -> T
    ) -> MapPublisher<T> {
        MapPublisher<T>(
            hoist: Subscriber.contraMap(transform),
            convert: receive,
            lower: identity
        )
    }
}

public extension Publisher {
    typealias MapErrorPublisher<T: Error> =
        Publisher<Output, OutputControl, OutputFailure, Output, OutputControl, T>

    func mapError<T: Error>(
        _ transform: @escaping (OutputFailure) -> T
    ) -> MapErrorPublisher<T>
    {
        MapErrorPublisher<T>(
            hoist: Subscriber.contraMapError(transform),
            convert: receive,
            lower: identity
        )
    }
}
