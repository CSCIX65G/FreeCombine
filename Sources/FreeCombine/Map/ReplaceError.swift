//
//  ReplaceError.swift
//  
//
//  Created by Van Simmons on 5/18/22.
//
public extension Publisher {
    func replaceError(_ f: @escaping (Swift.Error) -> Output) -> Publisher<Output> {
        .init { continuation, downstream in
            self(onStartup: continuation) { r in
                switch r {
                    case .value:
                        return try await downstream(r)
                    case .completion(.failure(let e)):
                        return try await downstream(.value(f(e)))
                    case .completion(.finished):
                        return try await downstream(r)
                }
            }
        }
    }
    
    func replaceError(with value: Output) -> Publisher<Output> {
        .init { continuation, downstream in
            self(onStartup: continuation) { r in
                switch r {
                    case .value:
                        return try await downstream(r)
                    case .completion(.failure):
                        return try await downstream(.value(value))
                    case .completion(.finished):
                        return try await downstream(r)
                }
            }
        }
    }
}
