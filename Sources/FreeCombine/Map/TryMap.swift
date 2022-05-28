//
//  TryMap.swift
//  
//
//  Created by Van Simmons on 5/15/22.
//
public extension Publisher {
    func tryMap<B>(_ f: @escaping (Output) async throws -> B) -> Publisher<B> {
        .init { continuation, downstream in
            self(onStartup: continuation) { r in
                guard !Task.isCancelled else {
                    return try await downstream(.completion(.failure(PublisherError.cancelled)))
                }
                switch r {
                    case .value(let a):
                        var b: B? = .none
                        do { b = try await f(a) }
                        catch { return try await downstream(.completion(.failure(error))) }
                        return try await downstream(.value(b!))
                    case let .completion(value):
                        return try await downstream(.completion(value))
                }
            }
        }
    }
}
