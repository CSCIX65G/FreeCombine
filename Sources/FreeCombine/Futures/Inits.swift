//
//  Inits.swift
//  
//
//  Created by Van Simmons on 7/30/22.
//
public extension Future {
    init(_ a: Output) {
        self = .init { continuation, downstream in .init {
            continuation.resume()
            return try await downstream(.success(a))
        } }
    }
}

public extension Future {
    init(_ generator: @escaping () async -> Output) {
        self = .init { continuation, downstream in .init {
            continuation.resume()
            return try await downstream(.success(generator()))
        } }
    }
}

public extension Future {
    init(_ e: Swift.Error) {
        self = .init { continuation, downstream in .init {
            continuation.resume()
            return try await downstream(.failure(e))
        } }
    }
}

public extension Future {
    init(_ generator: @escaping () async -> Swift.Error) {
        self = .init { continuation, downstream in  .init {
            continuation.resume()
            return try await downstream(.failure(generator()))
        } }
    }
}

public extension Future {
    init(_ result: Result<Output, Swift.Error>) {
        self = .init { continuation, downstream in .init {
            continuation.resume()
            return try await downstream(result)
        } }
    }
}

public extension Future {
    init(_ generator: @escaping () async -> Result<Output, Swift.Error>) {
        self = .init { continuation, downstream in  .init {
            continuation.resume()
            return try await downstream(generator())
        } }
    }
}
