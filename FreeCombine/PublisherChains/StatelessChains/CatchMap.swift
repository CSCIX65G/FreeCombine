//
//  TryMap.swift
//  FreeCombine
//
//  Created by Van Simmons on 4/25/20.
//  Copyright © 2020 ComputeCycles, LLC. All rights reserved.
//

public extension Publisher {
    func catchMap<T>(
        _ transform: @escaping (Output) throws -> T
    ) -> Publisher<Result<T, Error>, Error> {
        transformation(transformPublication: Publication.catchMap(transform))
    }
}
