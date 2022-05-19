//
//  File.swift
//  
//
//  Created by Van Simmons on 5/18/22.
//

public extension Publisher {
    func join<B>() -> Publisher<B> where Output == Publisher<B> {
        .init { continuation, downstream in
            self(onStartup: continuation) { r in guard !Task.isCancelled else { return .done }; switch r {
                case .value(let a):
                    return try await a(downstream).value
                case let .completion(.failure(error)):
                    return try await downstream(.completion(.failure(error)))
                case .completion(.finished):
                    return try await downstream(.completion(.finished))
            } }
        }
    }
}
