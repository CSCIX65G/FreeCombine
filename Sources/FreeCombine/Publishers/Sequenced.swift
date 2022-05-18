//
//  SequencePublisher.swift
//  
//
//  Created by Van Simmons on 5/15/22.
//
public extension Sequence {
    var asyncPublisher: Publisher<Element> {
        Sequenced(self)
    }
}

public func Sequenced<S: Sequence>(
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
