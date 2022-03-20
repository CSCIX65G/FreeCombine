//
//  Map.swift
//  
//
//  Created by Van Simmons on 3/16/22.
//

public extension Publisher {
    func map<B>(
        _ f: @escaping (Output) async -> B
    ) -> Publisher<B> {
        .init { continuation, downstream in
            self(onStartup: continuation) { r in guard !Task.isCancelled else { return .done }; switch r {
                case .value(let a):
                    return try await downstream(.value(f(a)))
                case .failure(let e):
                    return try await downstream(.failure(e))
                case .terminated:
                    return try await downstream(.terminated)
            } }
        }
    }
}
