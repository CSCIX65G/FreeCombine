//
//  TryFlatMap.swift
//  
//
//  Created by Van Simmons on 5/19/22.
//

public extension Publisher {
    func tryFlatMap<B>(
        _ f: @escaping (Output) async throws -> Publisher<B>
    ) -> Publisher<B> {
        .init { continuation, downstream in
            self(onStartup: continuation) { r in
                switch r {
                case .value(let a):
                    var c: Publisher<B>? = .none
                    do { c = try await f(a) }
                    catch { return try await downstream(.completion(.failure(error))) }
                    return try await c!(flattener(downstream)).task.value
                case let .completion(value):
                    return try await downstream(.completion(value))
            } }
        }
    }
}
