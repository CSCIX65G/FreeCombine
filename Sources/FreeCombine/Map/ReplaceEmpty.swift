//
//  ReplaceEmpty.swift
//  
//
//  Created by Van Simmons on 7/3/22.
//

public extension Publisher {
    func replaceEmpty(
        with value: Output
    ) -> Self {
        .init { continuation, downstream in
            let isEmpty: ValueRef<Bool> = ValueRef(value: true)
            return self(onStartup: continuation) { r in switch r {
                case .value(let a):
                    await isEmpty.set(value: false)
                    return try await downstream(.value(a))
                case let .completion(completion):
                    if await isEmpty.value {
                        _ = try await downstream(.value(value))
                    }
                    return try await downstream(.completion(completion))
            } }
        }
    }
}
