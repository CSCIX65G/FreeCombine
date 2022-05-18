//
//  File.swift
//  
//
//  Created by Van Simmons on 5/18/22.
//

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
