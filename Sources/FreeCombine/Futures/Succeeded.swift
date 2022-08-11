//
//  Succeeded.swift
//  
//
//  Created by Van Simmons on 8/11/22.
//
public func Succeeded<Output>(_ a: Output) -> Future<Output> {
    .init(a)
}

public extension Future {
    init(_ a: Output) {
        self = .init { continuation, downstream in .init {
            continuation.resume()
            return try await downstream(.success(a))
        } }
    }
}

public func Succeeded<Output>(_ generator: @escaping () async -> Output) -> Future<Output> {
    .init(generator)
}

public extension Future {
    init(_ generator: @escaping () async -> Output) {
        self = .init { continuation, downstream in .init {
            continuation.resume()
            return try await downstream(.success(generator()))
        } }
    }
}

