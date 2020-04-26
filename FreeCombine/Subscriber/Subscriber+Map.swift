//
//  Subscriber+Transforms.swift
//  FreeCombine
//
//  Created by Van Simmons on 4/14/20.
//  Copyright © 2020 ComputeCycles, LLC. All rights reserved.
//

extension Subscriber {
    func contraMap<T>(
        _ transform: @escaping (T) -> Value
    ) -> Subscriber<T, Failure> {
        .init { transform |> $0.map >>> self }
    }

//    func contraMap<T>(
//        _ transform: @escaping (T) throws -> Value
//    ) throws -> Subscriber<T, Failure> {
//        .init { transform |> $0.map >>> self }
//    }

    func contraMapError<T: Error>(
        _ transform: @escaping (T) -> Failure
    ) -> Subscriber<Value, T> {
        .init { transform |> $0.mapError >>> self }
    }
}
