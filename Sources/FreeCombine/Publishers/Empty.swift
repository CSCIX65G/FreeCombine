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
    static var none: Self {
        Empty(Output.self)
    }

    init(
        onCancel: @Sendable @escaping () -> Void = { },
        _: Output.Type = Output.self
    ) {
        self = .init { continuation, downstream in
            .init {
                continuation?.resume()
                return try await downstream(.completion(.finished))
            }
        }
    }
}
