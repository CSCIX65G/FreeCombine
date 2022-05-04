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
            Task { try await withTaskCancellationHandler(handler: onCancel) {
                continuation?.resume()
                guard !Task.isCancelled else { return .done }
                return try await downstream(.completion(.finished))
            } }
        }
    }
}
