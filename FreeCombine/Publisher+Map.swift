//
//  Composition.swift
//  FreeCombine
//
//  Created by Van Simmons on 4/13/20.
//  Copyright © 2020 ComputeCycles, LLC. All rights reserved.
//

// FlatMaps
//extension Publication {
//    static func flatMap<T>(
//        _ transform: @escaping (Input) -> Producer<T, OutputFailure>
//    ) -> (Self) -> Publication<Output, OutputControl, OutputFailure, T, OutputControl, OutputFailure> {
//
//    }
//}

// Maps
public extension Publisher {
    typealias MapPublisher<T> =
        Publisher<Output, OutputControl, OutputFailure, T, OutputControl, OutputFailure>
    
    func map<T>(
        _ transform: @escaping (Output) -> T
    ) -> MapPublisher<T> {
        MapPublisher<T>(
            hoist: Subscriber<T, OutputFailure>.contraMap(transform, identity),
            convert: receive,
            lower: identity
        )
    }
}

public extension Publisher {
    typealias MapErrorPublisher<T: Error> =
        Publisher<Output, OutputControl, OutputFailure,
        Output, OutputControl, T>

    func mapError<T: Error>(
        _ transform: @escaping (OutputFailure) -> T
    ) -> MapErrorPublisher<T>
    {
        MapErrorPublisher<T>(
            hoist: Subscriber<Output, T>.contraMapError(transform),
            convert: receive,
            lower: identity
        )
    }
}
