//
//  TryMap.swift
//  FreeCombine
//
//  Created by Van Simmons on 4/26/20.
//  Copyright © 2020 ComputeCycles, LLC. All rights reserved.
//

public extension Publisher {
    func tryMap<T>(
        _ transform: @escaping (Output) throws -> T
    ) -> Publisher<T, Error> {
        mapTransformation(preSubscriber: Publication.tryMap(transform))
    }
}
