//
//  Just.swift
//  
//
//  Created by Van Simmons on 3/15/22.
//
public func Just<Element>(_ a: Element) -> Publisher<Element> {
    .init(a)
}

public extension Publisher {
    init(_ a: Output) {
        self = .init { continuation, downstream in
            .init {
                continuation.resume()
                return try await downstream(.value(a)) == .more ? try await downstream(.completion(.finished)) : .done
            }
        }
    }
}

public func Just<Element>(_ generator: @escaping () async -> Element) -> Publisher<Element> {
    .init(generator)
}

public extension Publisher {
    init(_ generator: @escaping () async -> Output) {
        self = .init { continuation, downstream in
            .init {
                continuation.resume()
                return try await downstream(.value(generator())) == .more ? try await downstream(.completion(.finished)) : .done
            }
        }
    }
}

public func Just<Element>(_ a: AsyncStream<Element>.Result) -> Publisher<Element> {
    .init(a)
}

public extension Publisher {
    init(_ result: AsyncStream<Output>.Result) {
        self = .init { continuation, downstream in
            .init {
                continuation.resume()
                return try await downstream(result) == .more ? try await downstream(.completion(.finished)) : .done
            }
        }
    }
}

public func Just<Element>(_ generator: @escaping () async -> AsyncStream<Element>.Result) -> Publisher<Element> {
    .init(generator)
}

public extension Publisher {
    init(_ generator: @escaping () async -> AsyncStream<Output>.Result) {
        self = .init { continuation, downstream in
            .init {
                continuation.resume()
                return try await downstream(generator()) == .more ? try await downstream(.completion(.finished)) : .done
            }
        }
    }
}
