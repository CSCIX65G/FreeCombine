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
            self(onStartup: continuation) { r in guard !Task.isCancelled else { return .done }; switch r {
                case .value(let a):
                    var bPub: Publisher<B>? = .none
                    do { bPub = try await f(a) }
                    catch { return try await downstream(.completion(.failure(error))) }
                    return try await bPub!(flattener(downstream)).task.value
                case let .completion(value):
                    return try await downstream(.completion(value))
            } }
        }
    }
}
