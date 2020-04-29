//
//  MapError.swift
//  FreeCombine
//
//  Created by Van Simmons on 4/25/20.
//  Copyright © 2020 ComputeCycles, LLC. All rights reserved.
//

public extension Publisher {
    func mapError<T: Error>(
        _ transform: @escaping (Failure) -> T
    ) -> Publisher<Output, T> {
        transformation(transformPublication: Publication.mapError(transform))
    }
}
