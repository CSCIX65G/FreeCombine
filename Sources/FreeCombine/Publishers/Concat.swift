//
//  Concat.swift
//  
//
//  Created by Van Simmons on 5/17/22.
//

func flattener<B>(
    _ downstream: @Sendable @escaping (AsyncStream<B>.Result) async throws -> Demand
) -> @Sendable (AsyncStream<B>.Result) async throws -> Demand {
    { b in switch b {
        case .completion(.finished):
            return .more
        case .value, .completion(.failure):
            return try await downstream(b)
    } }
}

public extension Publisher  {
    func concat(_ other: Publisher<Output>) -> Publisher<Output> {
        .init(concatenating: [self, other])
    }
}

public func Concat<Element>(
    onCancel: @escaping () -> Void = { },
    _ publishers: Publisher<Element>...
) -> Publisher<Element> {
    .init(concatenating: publishers)
}

public extension Publisher {
    init<S: Sequence>(
        onCancel: @Sendable @escaping () -> Void = {  },
        concatenating publishers: S
    ) where S.Element == Publisher<Output> {
        self = .init { continuation, downstream  in
            let flattenedDownstream = flattener(downstream)
            return .init { try await withTaskCancellationHandler(handler: onCancel) {
                continuation?.resume()
                guard !Task.isCancelled else { return .done }
                for p in publishers {
                    let t = await p(flattenedDownstream)
                    guard !Task.isCancelled else {
                        return .done
                    }
                    guard try await t.value == .more else { return .done }
                }
                return try await downstream(.completion(.finished))
            } }
        }
    }
}

public func Concat<Element>(
    onCancel: @escaping () -> Void = { },
    _ publishers: @escaping () async -> Publisher<Element>?
) -> Publisher<Element> {
    .init(flattening: publishers)
}

public extension Publisher {
    init(
        onCancel: @Sendable @escaping () -> Void = { },
        flattening: @escaping () async -> Publisher<Output>?
    ) {
        self = .init { continuation, downstream  in
            let flattenedDownstream = flattener(downstream)
            return .init { try await withTaskCancellationHandler(handler: onCancel) {
                continuation?.resume()
                guard !Task.isCancelled else { return .done }
                while let p = await flattening() {
                    let t = await p(flattenedDownstream)
                    guard !Task.isCancelled else {
                        return .done
                    }
                    guard try await t.value == .more else { return .done }
                }
                return try await downstream(.completion(.finished))
            } }
        }
    }
}
