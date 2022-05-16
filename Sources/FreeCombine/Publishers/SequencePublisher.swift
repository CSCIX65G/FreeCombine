//
//  SequencePublisher.swift
//  
//
//  Created by Van Simmons on 5/15/22.
//
public extension Sequence {
    var asyncPublisher: Publisher<Element> {
        SequencePublisher(self)
    }
}

public func SequencePublisher<S: Sequence>(
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
                    do {
                        for a in sequence {
                            guard !Task.isCancelled else { throw PublisherError.cancelled }
                            guard try await downstream(.value(a)) == .more else { return .done }
                        }
                        guard !Task.isCancelled else { throw PublisherError.cancelled }
                        return try await downstream(.completion(.finished))
                    } catch PublisherError.cancelled {
                        onCancel()
                        throw PublisherError.cancelled
                    }
                }
            }
        }
    }
}

public func SequencePublisher<Element>(
    onCancel: @Sendable @escaping () -> Void = { },
    _ sequence: @escaping () -> Element?
) -> Publisher<Element> {
    .init(onCancel: onCancel, sequence)
}

public extension Publisher {
    init(
        onCancel: @Sendable @escaping () -> Void = { },
        _ next: @escaping () async throws -> Output?
    ) {
        self = .init { continuation, downstream in
            .init { try await withTaskCancellationHandler(handler: onCancel) {
                continuation?.resume()
                guard !Task.isCancelled else {
                    return .done
                }
                do {
                    while let a = try await next() {
                        guard !Task.isCancelled else {
                            return .done
                        }
                        guard try await downstream(.value(a)) == .more else {
                            return .done
                        }
                    }
                    guard !Task.isCancelled else {
                        return .done
                    }
                    return try await downstream(.completion(.finished))
                } catch {
                    return try await downstream(.completion(.failure(error)))
                }
            } }
        }
    }
}
