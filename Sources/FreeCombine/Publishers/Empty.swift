//
//  Empty.swift
//  
//
//  Created by Van Simmons on 4/10/22.
//
public func Empty<Element>(
    onCancel: @Sendable @escaping () -> Void = { },
    _ elementType: Element.Type = Element.self
) -> Publisher<Element> {
    .init(onCancel: onCancel, elementType)
}

public extension Publisher {
    init(
        onCancel: @Sendable @escaping () -> Void = { },
        _: Output.Type = Output.self
    ) {
        self = .init { continuation, downstream in
            Task {
                continuation?.resume()
                return try await withTaskCancellationHandler(handler: onCancel) {
                    guard !Task.isCancelled else { return .done }
                    do {
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
