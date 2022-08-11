//
//  Resolved.swift
//  
//
//  Created by Van Simmons on 8/11/22.
//

public func Resolved<Output>(_ result: Result<Output, Swift.Error>) -> Future<Output> {
    .init(result)
}

public extension Future {
    init(_ result: Result<Output, Swift.Error>) {
        self = .init { continuation, downstream in .init {
            continuation.resume()
            return try await downstream(result)
        } }
    }
}

public func Resolved<Output>(_ generator: @escaping () async -> Result<Output, Swift.Error>) -> Future<Output> {
    .init(generator)
}

public extension Future {
    init(_ generator: @escaping () async -> Result<Output, Swift.Error>) {
        self = .init { continuation, downstream in  .init {
            continuation.resume()
            return try await downstream(generator())
        } }
    }
}
