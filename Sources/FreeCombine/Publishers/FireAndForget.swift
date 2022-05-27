//
//  FireAndForget.swift
//  
//
//  Created by Van Simmons on 5/26/22.
//
public func FireAndForget<Element>(
    onCancel: @Sendable @escaping () -> Void = { },
    _ elementType: Element.Type = Element.self,
    operation: @escaping () async throws -> Void
) -> Publisher<Element> {
    .init(onCancel: onCancel, elementType)
}

public extension Publisher {
    static func fireAndForget(_ f: @escaping () async throws -> Void) -> Self {
        FireAndForget(Output.self, operation: f)
    }

    init(
        onCancel: @Sendable @escaping () -> Void = { },
        _: Output.Type = Output.self,
        operation: @escaping () async throws -> Void
    ) {
        self = .init { continuation, downstream in
            .init {
                continuation?.resume()
                do {
                    try await operation()
                    guard !Task.isCancelled else {
                        _ = try await downstream(.completion(.failure(PublisherError.cancelled)))
                        throw PublisherError.cancelled
                    }
                    return try await downstream(.completion(.finished))
                } catch {
                    return try await downstream(.completion(.failure(error)))
                }
            }
        }
    }
}
