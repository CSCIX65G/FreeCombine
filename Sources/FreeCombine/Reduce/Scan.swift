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
        return .init { continuation, downstream in
            let currentValue: ValueRef<T> = ValueRef(value: initialValue)
            return self(onStartup: continuation) { r in
                guard !Task.isCancelled else { return .done }
                switch r {
                    case .value(let a):
                        await currentValue.set(value: transform(currentValue.value, a))
                        return try await downstream(.value(currentValue.value))
                    case let .completion(value):
                        return try await downstream(.completion(value))
                }
            }
        }
    }
}
