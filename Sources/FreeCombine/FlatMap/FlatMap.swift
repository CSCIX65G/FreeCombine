//
//  FlatMap.swift
//  
//
//  Created by Van Simmons on 5/18/22.
//
public extension Publisher {
    func flatMap<B>(
        _ transform: @escaping (Output) async -> Publisher<B>
    ) -> Publisher<B> {
        .init { continuation, downstream in self(onStartup: continuation) { r in switch r {
            case .value(let a):
                return try await transform(a)(flattener(downstream)).value
            case let .completion(value):
                return try await downstream(.completion(value))
        } } }
    }
}
