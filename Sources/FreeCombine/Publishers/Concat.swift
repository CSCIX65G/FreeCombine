//
//  Concat.swift
//  
//
//  Created by Van Simmons on 5/17/22.
//
public extension Publisher  {
    func concat(_ other: Publisher<Output>) -> Publisher<Output> {
        .init(concatenating: [self, other])
    }
}

public func Concat<Output, S: Sequence>(
    _ publishers: S
) -> Publisher<Output> where S.Element == Publisher<Output>{
    .init(concatenating: publishers)
}

public extension Publisher {
    init<S: Sequence>(
        concatenating publishers: S
    ) where S.Element == Publisher<Output> {
        self = .init { continuation, downstream  in
            let flattenedDownstream = flattener(downstream)
            return .init {
                continuation?.resume()
                for p in publishers {
                    let t = await p(flattenedDownstream)
                    guard try await t.value == .more else { return .done }
                }
                return try await downstream(.completion(.finished))
            }
        }
    }
}

public func Concat<Element>(
    _ publishers: Publisher<Element>...
) -> Publisher<Element> {
    .init(concatenating: publishers)
}

public extension Publisher {
    init(
        concatenating publishers: Publisher<Output>...
    ) {
        self = .init(concatenating: publishers)
    }
}

public func Concat<Element>(
    _ publishers: @escaping () async -> Publisher<Element>?
) -> Publisher<Element> {
    .init(flattening: publishers)
}

public extension Publisher {
    init(
        flattening: @escaping () async -> Publisher<Output>?
    ) {
        self = .init { continuation, downstream  in
            let flattenedDownstream = flattener(downstream)
            return .init {
                continuation?.resume()
                while let p = await flattening() {
                    let t = await p(flattenedDownstream)
                    guard try await t.value == .more else { return .done }
                }
                return try await downstream(.completion(.finished))
            }
        }
    }
}
