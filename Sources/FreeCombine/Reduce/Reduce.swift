//
//  Reduce.swift
//  
//
//  Created by Van Simmons on 5/19/22.
//

public extension Publisher {
    func reduce<T>(
        _ initialValue: T,
        _ transform: @escaping (T, Output) async -> T
    ) -> Publisher<T> {
        return .init { continuation, downstream in
            let currentValue: ValueRef<T> = ValueRef(value: initialValue)
            return self(onStartup: continuation) { r in
                guard !Task.isCancelled else {
                    return try await downstream(.completion(.failure(PublisherError.cancelled)))
                }
                switch r {
                    case .value(let a):
                        await currentValue.set(value: transform(currentValue.value, a))
                        return .more
                    case let .completion(value):
                        _ = try await downstream(.value(currentValue.value))
                        return try await downstream(.completion(value))
                }
            }
        }
    }
}
