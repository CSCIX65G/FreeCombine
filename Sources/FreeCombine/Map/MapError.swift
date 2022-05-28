//
//  MapError.swift
//  
//
//  Created by Van Simmons on 5/18/22.
//

public extension Publisher {
    func mapError<NewE: Swift.Error>(
        _ f: @escaping (Swift.Error) -> NewE
    ) -> Self {
        .init { continuation, downstream in
            self(onStartup: continuation) { r in switch r {
                case .value:
                    return try await downstream(r)
                case .completion(.failure(let e)):
                    return try await downstream(.completion(.failure(f(e))))
                case .completion(.finished):
                    return try await downstream(r)
            } }
        }
    }
}
