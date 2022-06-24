//
//  FireAndForget.swift
//  
//
//  Created by Van Simmons on 5/26/22.
//
public func SideEffect<Element>(
    _ elementType: Element.Type = Element.self,
    operation: @escaping () async throws -> Void
) -> Publisher<Element> {
    .init(elementType)
}

public extension Publisher {
    static func fireAndForget(_ f: @escaping () async throws -> Void) -> Self {
        SideEffect(Output.self, operation: f)
    }

    init(
        _: Output.Type = Output.self,
        operation: @escaping () async throws -> Void
    ) {
        self = .init { continuation, downstream in
            .init {
                continuation.resume()
                do {
                    try await operation()
                    guard !Task.isCancelled else {
                        return try await handleCancellation(of: downstream)
                    }
                    return try await downstream(.completion(.finished))
                } catch {
                    return try await downstream(.completion(.failure(error)))
                }
            }
        }
    }
}
