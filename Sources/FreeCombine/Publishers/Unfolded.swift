//
//  File.swift
//  
//
//  Created by Van Simmons on 5/18/22.
//
public extension Sequence {
    var asyncPublisher: Publisher<Element> {
        Unfolded(self)
    }
}

public func Unfolded<S: Sequence>(
    onCancel: @Sendable @escaping () -> Void = { },
    _ sequence: S
) -> Publisher<S.Element> {
    .init(onCancel: onCancel, sequence)
}

public extension Publisher {
    init<S: Sequence>(
        onCancel: @Sendable @escaping () -> Void,
        _ sequence: S
    ) where S.Element == Output {
        self = .init { continuation, downstream in
            Task<Demand, Swift.Error> {
                continuation?.resume()
                return try await withTaskCancellationHandler(handler: onCancel) {
                    for a in sequence {
                        guard !Task.isCancelled else { throw PublisherError.cancelled }
                        guard try await downstream(.value(a)) == .more else { return .done }
                    }
                    guard !Task.isCancelled else { throw PublisherError.cancelled }
                    return try await downstream(.completion(.finished))
                }
            }
        }
    }
}

public func Unfolded<Element>(
    onCancel: @Sendable @escaping () -> Void = { },
    _ generator: @escaping () -> Element?
) -> Publisher<Element> {
    .init(onCancel: onCancel, generator)
}

public extension Publisher {
    init(
        onCancel: @Sendable @escaping () -> Void = { },
        _ generator: @escaping () async throws -> Output?
    ) {
        self = .init { continuation, downstream in
            Task {
                continuation?.resume()
                return try await withTaskCancellationHandler(handler: onCancel) {
                    while let a = try await generator() {
                        guard !Task.isCancelled else { throw PublisherError.cancelled }
                        guard try await downstream(.value(a)) == .more else { return .done }
                    }
                    guard !Task.isCancelled else { throw PublisherError.cancelled }
                    return try await downstream(.completion(.finished))
                }
            }
        }
    }
}
