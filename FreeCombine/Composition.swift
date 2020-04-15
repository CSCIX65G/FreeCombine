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
extension Publisher {
    func map<T>(
        _ transform: @escaping (Output) -> T
    ) -> Publisher<Output, OutputControl, OutputFailure, T, OutputControl, OutputFailure> {
        Publisher<Output, OutputControl, OutputFailure, T, OutputControl, OutputFailure>(
            hoist: recast(Subscriber<Output, OutputFailure>.map(transform)),
            convert: receive,
            lower: identity
        )
    }

    func contraMap(
        _ transform: @escaping (Demand) -> Demand
    ) -> Publisher<Output, OutputControl, OutputFailure, Output, OutputControl, OutputFailure> {
        Publisher<Output, OutputControl, OutputFailure, Output, OutputControl, OutputFailure>(
            hoist: Subscriber<Output, OutputFailure>.contraMap(transform),
            convert: receive,
            lower: identity
        )
    }

    func mapError<T: Error>(
        _ transform: @escaping (OutputFailure) -> T
    ) -> Publisher<Output, OutputControl, OutputFailure, Output, OutputControl, T> {
        Publisher<Output, OutputControl, OutputFailure, Output, OutputControl, T>(
            hoist: recast(Subscriber<Output, OutputFailure>.mapError(transform)),
            convert: receive,
            lower: identity
        )
    }
}
