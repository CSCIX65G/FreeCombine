//
//  Publisher.swift
//  
//
//  Created by Van Simmons on 3/15/22.
//

public enum Demand: Equatable {
    case more
    case done
}

public struct Publisher<Output> {
    public enum Error: Swift.Error, CaseIterable, Equatable {
        case cancelled
    }
    private let call: (
        UnsafeContinuation<Void, Never>?,
        @escaping (AsyncStream<Output>.Result) async -> Demand
    ) -> Task<Demand, Swift.Error>
    init(
        _ call: @escaping (
            UnsafeContinuation<Void, Never>?,
            @escaping (AsyncStream<Output>.Result) async -> Demand
        ) -> Task<Demand, Swift.Error>
    ) {
        self.call = call
    }
}

public extension Publisher {
    func sink(
        onStartup: UnsafeContinuation<Void, Never>? = .none,
        _ f: @escaping (AsyncStream<Output>.Result) async -> Demand
    ) -> Task<Demand, Swift.Error> {
        self(onStartup: onStartup, f)
    }

    @discardableResult
    func callAsFunction(
        onStartup: UnsafeContinuation<Void, Never>? = .none,
        _ f: @escaping (AsyncStream<Output>.Result) async -> Demand
    ) -> Task<Demand, Swift.Error> {
        call(onStartup, { result in
            let demand = await f(result)
            await Task.yield()
            return demand
        })
    }

    func sink(
        _ f: @escaping (AsyncStream<Output>.Result) async -> Demand
    ) async -> Task<Demand, Swift.Error> {
        await self(f)
    }

    @discardableResult
    func callAsFunction(
        _ f: @escaping (AsyncStream<Output>.Result) async -> Demand
    ) async -> Task<Demand, Swift.Error> {
        var t: Task<Demand, Swift.Error>! = .none
        await withUnsafeContinuation { continuation in
            t = call(continuation, { result in
                let demand = await f(result)
                await Task.yield()
                return demand
            })
        }
        return t
    }
}
