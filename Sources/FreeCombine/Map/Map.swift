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
                    let value = await f(a)
                    guard !Task.isCancelled else { throw PublisherError.cancelled }
                    return try await downstream(.value(value))
                case let .completion(value):
                    return try await downstream(.completion(value))
            } }
        }
    }
}
