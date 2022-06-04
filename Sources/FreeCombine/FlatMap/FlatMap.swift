//
//  FlatMap.swift
//  
//
//  Created by Van Simmons on 5/18/22.
//
public extension Publisher {
    func flatMap<B>(
        _ f: @escaping (Output) async -> Publisher<B>
    ) -> Publisher<B> {
        .init { continuation, downstream in
            self(onStartup: continuation) { r in switch r {
                case .value(let a):
                    let c = await f(a)(flattener(downstream))
                    return try await c.value
                case let .completion(value):
                    return try await downstream(.completion(value))
            } }
        }
    }
}
