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
extension Publication {
    func map<T>(
        _ transform: @escaping (Output) -> T
    ) -> Publication<Output, OutputControl, OutputFailure, T, OutputControl, OutputFailure> {
        Publication<Output, OutputControl, OutputFailure, T, OutputControl, OutputFailure>(
            hoist: recast(Subscriber<Output, OutputFailure>.map(transform)),
            subscribe: receive,
            lower: identity
        )
    }

    func contraMap(
        _ transform: @escaping (Demand) -> Demand
    ) -> Publication<Output, OutputControl, OutputFailure, Output, OutputControl, OutputFailure> {
        Publication<Output, OutputControl, OutputFailure, Output, OutputControl, OutputFailure>(
            hoist: Subscriber<Output, OutputFailure>.contraMap(transform),
            subscribe: receive,
            lower: identity
        )
    }

    func mapError<T: Error>(
        _ transform: @escaping (OutputFailure) -> T
    ) -> Publication<Output, OutputControl, OutputFailure, Output, OutputControl, T> {
        Publication<Output, OutputControl, OutputFailure, Output, OutputControl, T>(
            hoist: recast(Subscriber<Output, OutputFailure>.mapError(transform)),
            subscribe: receive,
            lower: identity
        )
    }
}
