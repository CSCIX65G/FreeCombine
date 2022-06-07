//
//  TryCompactMap.swift
//  
//
//  Created by Van Simmons on 5/18/22.
//
public extension Publisher {
    func tryCompactMap<B>(
        _ transform: @escaping (Output) async throws -> B?
    ) -> Publisher<B> {
        .init { continuation, downstream in
            self(onStartup: continuation) { r in switch r {
                case .value(let a):
                    var c: B? = .none
                    do { c = try await transform(a) }
                    catch { return try await downstream(.completion(.failure(error))) }
                    guard let b = c else { return .more }
                    return try await downstream(.value(b))
                case let .completion(value):
                    return try await downstream(.completion(value))
            } }
        }
    }
}
