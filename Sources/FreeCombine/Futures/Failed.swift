//
//  Failed.swift
//  
//
//  Created by Van Simmons on 8/11/22.
//
public func Failed<Output>(_ e: Swift.Error) -> Future<Output> {
    .init(e)
}

public extension Future {
    init(_ e: Swift.Error) {
        self = .init { continuation, downstream in .init {
            continuation.resume()
            return try await downstream(.failure(e))
        } }
    }
}

public func Fail<Output>(_ generator: @escaping () async -> Swift.Error) -> Future<Output> {
    .init(generator)
}

public extension Future {
    init(_ generator: @escaping () async -> Swift.Error) {
        self = .init { continuation, downstream in  .init {
            continuation.resume()
            return try await downstream(.failure(generator()))
        } }
    }
}
