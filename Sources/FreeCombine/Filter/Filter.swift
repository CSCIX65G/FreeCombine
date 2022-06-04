//
//  File.swift
//  
//
//  Created by Van Simmons on 6/4/22.
//
public extension Publisher {
    func filter(
        _ isIncluded: @escaping (Output) async -> Bool
    ) -> Self {
        .init { continuation, downstream in
            self(onStartup: continuation) { r in
                switch r {
                case .value(let a):
                    guard await isIncluded(a) else { return .more }
                    return try await downstream(r)
                case let .completion(value):
                    return try await downstream(.completion(value))
            } }
        }
    }
}
