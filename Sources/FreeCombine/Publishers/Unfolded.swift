//
//  Unfolded.swift
//  
//
//  Created by Van Simmons on 5/18/22.
//
public extension Sequence {
    var asyncPublisher: Publisher<Element> {
        Unfolded(self)
    }
}

public func Unfolded<S: Sequence>(_ sequence: S) -> Publisher<S.Element> {
    .init(sequence)
}

public extension Publisher {
    init<S: Sequence>(_ sequence: S) where S.Element == Output {
        self = .init { continuation, downstream in
            Cancellable<Demand> {
                continuation?.resume()
                for a in sequence {
                    guard !Task.isCancelled else {
                        return try await downstream(.completion(.failure(PublisherError.cancelled)))
                    }
                    guard try await downstream(.value(a)) == .more else { return .done }
                }
                guard !Task.isCancelled else {
                    return try await downstream(.completion(.failure(PublisherError.cancelled)))
                }
                return try await downstream(.completion(.finished))
            }
        }
    }
}

public func Unfolded<Element>(
    _ generator: @escaping () -> Element?
) -> Publisher<Element> {
    .init(generator)
}

public extension Publisher {
    init(_ generator: @escaping () async throws -> Output?) {
        self = .init { continuation, downstream in
                .init {
                    continuation?.resume()
                    while let a = try await generator() {
                        guard !Task.isCancelled else {
                            return try await downstream(.completion(.failure(PublisherError.cancelled)))
                        }
                        guard try await downstream(.value(a)) == .more else { return .done }
                    }
                    guard !Task.isCancelled else {
                        return try await downstream(.completion(.failure(PublisherError.cancelled)))
                    }
                    return try await downstream(.completion(.finished))
                }
        }
    }
}
