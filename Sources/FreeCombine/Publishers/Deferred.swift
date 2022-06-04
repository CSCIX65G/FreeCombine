//
//  Deferred.swift
//  
//
//  Created by Van Simmons on 5/18/22.
//
public func Deferred<Element>(from flattable: Publisher<Element>) -> Publisher<Element> {
    .init(from: flattable)
}

extension Publisher {
    init(from flattable: Publisher<Output>) {
        self = .init { continuation, downstream in
            .init {
                continuation?.resume()
                return try await flattable(downstream).value
            }
        }
    }
}

public func Deferred<Element>(
    flattener: @escaping () async -> Publisher<Element>
) -> Publisher<Element> {
    .init(from: flattener)
}

extension Publisher {
    init(from flattener: @escaping () async throws -> Publisher<Output>) {
        self = .init { continuation, downstream in
            .init {
                continuation?.resume()
                let p = try await flattener()
                let c = await p(downstream)
                return try await c.value
            }
        }
    }
}
