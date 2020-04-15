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
            hoist: recast(DownstreamSubscriber.map(transform)),
            convert: receive,
            lower: identity
        )
    }

    typealias ContraMapPublisher =
        Publisher<Output, OutputControl, OutputFailure, Output, OutputControl, OutputFailure>
    
    func contraMap(
        _ transform: @escaping (Demand) -> Demand
    ) ->  ContraMapPublisher {
        ContraMapPublisher (
            hoist: DownstreamSubscriber.contraMap(transform),
            convert: receive,
            lower: identity
        )
    }

    typealias MapErrorPublisher<T: Error> =
        Publisher<Output, OutputControl, OutputFailure, Output, OutputControl, T>
    
    func mapError<T: Error>(
        _ transform: @escaping (OutputFailure) -> T
    ) -> MapErrorPublisher<T> {
        MapErrorPublisher<T>(
            hoist: recast(DownstreamSubscriber.mapError(transform)),
            convert: receive,
            lower: identity
        )
    }
}
