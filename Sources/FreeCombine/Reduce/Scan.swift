//
//  Scan.swift
//  
//
//  Created by Van Simmons on 5/18/22.
//
public extension Publisher {
    func scan<T>(
        _ initialValue: T,
        _ transform: @escaping (T, Output) async -> T
    ) -> Publisher<T> {
        let currentValue: PublisherRef<T> = PublisherRef(value: initialValue)
        return .init { continuation, downstream in
            self(onStartup: continuation) { r in
                guard !Task.isCancelled else { return .done }
                switch r {
                    case .value(let a):
                        await currentValue.set(value: transform(currentValue.value, a))
                        return try await downstream(.value(currentValue.value))
                    case let .completion(.failure(error)):
                        return try await downstream(.completion(.failure(error)))
                    case .completion(.finished):
                        return try await downstream(.completion(.finished))
                }
            }
        }
    }
}
