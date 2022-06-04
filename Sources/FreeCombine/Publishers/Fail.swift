//
//  Fail.swift
//  
//
//  Created by Van Simmons on 5/18/22.
//
public func Fail<Element>(
    _ t: Element.Type = Element.self,
    _ e: Swift.Error
) -> Publisher<Element> {
    .init(t, e)
}

public extension Publisher {
    init(
        _: Output.Type = Output.self,
        _ error: Swift.Error
    ) {
        self = .init { continuation, downstream in
            .init {
                try await downstream(.completion(.failure(error)))
            }
        }
    }
}
