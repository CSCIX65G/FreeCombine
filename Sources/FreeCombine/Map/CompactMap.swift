//
//  CompactMap.swift
//  
//
//  Created by Van Simmons on 5/18/22.
//
public extension Publisher {
    func compactMap<B>(
        _ transform: @escaping (Output) async -> B?
    ) -> Publisher<B> {
        .init { continuation, downstream in
            self(onStartup: continuation) { r in
                switch r {
                case .value(let a):
                    guard let b = await transform(a) else { return .more }
                    return try await downstream(.value(b))
                case let .completion(value):
                    return try await downstream(.completion(value))
            } }
        }
    }
}
