//
//  Print.swift
//  
//
//  Created by Van Simmons on 6/6/22.
//
public extension Publisher {
    func print(prefix: String = "") -> Self {
        return .init { continuation, downstream in
            _ = Swift.print("\(prefix) received subscriber: \(type(of: downstream))")
            return self(onStartup: continuation) { r in
                switch r {
                    case .value(let a):
                        _ = Swift.print("\(prefix) received value: \(a))")
                    case .completion(.finished):
                        _ = Swift.print("\(prefix) received .completion(.finished))")
                    case .completion(.cancelled):
                        _ = Swift.print("\(prefix) received .completion(.cancelled))")
                    case let .completion(.failure(error)):
                        _ = Swift.print("\(prefix) received .completion(.failure(\(error)))")
                }
                let demand = try await downstream(r)
                _ = Swift.print("\(prefix) received Demand(\(demand)))")
                return demand
            }
        }
    }
}
