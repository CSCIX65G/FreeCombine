//
//  DropFirst.swift
//  
//
//  Created by Van Simmons on 6/4/22.
//
public extension Publisher {
    func dropFirst(
        _ count: Int = 1
    ) -> Self {
        .init { continuation, downstream in
            let currentValue: ValueRef<Int> = ValueRef(value: count + 1)
            return self(onStartup: continuation) { r in
                let current = await currentValue.value - 1
                try await currentValue.set(value: max(0, current))
                switch r {
                case .value:
                    guard current <= 0 else { return .more }
                    return try await downstream(r)
                case let .completion(value):
                    return try await downstream(.completion(value))
            } }
        }
    }
}
