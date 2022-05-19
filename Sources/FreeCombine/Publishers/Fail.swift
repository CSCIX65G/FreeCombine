//
//  Fail.swift
//  
//
//  Created by Van Simmons on 5/18/22.
//
public func Fail<Element>(
    onCancel: @Sendable @escaping () -> Void = { },
    _ t: Element.Type = Element.self,
    _ e: Swift.Error
) -> Publisher<Element> {
    .init(onCancel: onCancel, t, e)
}

public extension Publisher {
    init(
        onCancel: @Sendable @escaping () -> Void = { },
        _: Output.Type = Output.self,
        _ error: Swift.Error
    ) {
        self = .init { continuation, downstream in
            Task { try await withTaskCancellationHandler(handler: onCancel) {
                guard !Task.isCancelled else { throw PublisherError.cancelled }
                return try await downstream(.completion(.failure(error)))
            } }
        }
    }
}
