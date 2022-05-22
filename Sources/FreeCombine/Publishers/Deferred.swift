//
//  Deferred.swift
//  
//
//  Created by Van Simmons on 5/18/22.
//
public func Deferred<Element>(
    onCancel: @Sendable @escaping () -> Void = { },
    from flattable: Publisher<Element>
) -> Publisher<Element> {
    .init(onCancel: onCancel, from: flattable)
}

extension Publisher {
    init(
        onCancel: @Sendable @escaping () -> Void = { },
        from flattable: Publisher<Output>
    ) {
        self = .init { continuation, downstream in
            .init{ try await withTaskCancellationHandler(handler: onCancel) {
                continuation?.resume()
                guard !Task.isCancelled else { throw PublisherError.cancelled }
                return try await flattable(downstream).task.value
            } }
        }
    }
}

public func Deferred<Element>(
    onCancel: @Sendable @escaping () -> Void = { },
    flattener: @escaping () async -> Publisher<Element>
) -> Publisher<Element> {
    .init(onCancel: onCancel, from: flattener)
}

extension Publisher {
    init(
        onCancel: @Sendable @escaping () -> Void = { },
        from flattening: @escaping () async throws -> Publisher<Output>
    ) {
        self = .init { continuation, downstream in
            .init { try await withTaskCancellationHandler(handler: onCancel) {
                continuation?.resume()
                guard !Task.isCancelled else { throw PublisherError.cancelled }
                return try await flattening()(downstream).task.value
            } }
        }
    }
}
