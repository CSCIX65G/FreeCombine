//
//  Map.swift
//  
//
//  Created by Van Simmons on 3/16/22.
//

public extension Publisher {
    func map<B>(
        _ transform: @escaping (Output) async -> B
    ) -> Publisher<B> {
        .init { continuation, downstream in
            self(onStartup: continuation) { r in switch r {
                case .value(let a):
                    return try await downstream(.value(transform(a)))
                case let .completion(value):
                    return try await downstream(.completion(value))
            } }
        }
    }
}

public extension Future {
    func map<B>(
        _ transform: @escaping (Output) async -> B
    ) -> Future<B> {
        .init { continuation, downstream in
            self(onStartup: continuation) { r in switch r {
                case .success(let a):
                    return try await downstream(.success(transform(a)))
                case let .failure(error):
                    return try await downstream(.failure(error))
            } }
        }
    }
}
