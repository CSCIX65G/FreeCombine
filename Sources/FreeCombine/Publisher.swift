//
//  Publisher.swift
//  
//
//  Created by Van Simmons on 3/15/22.
//

public extension AsyncStream where Element: Sendable {
    enum Result: Sendable {
        case value(Element)
        case failure(Error)
        case terminated
    }
}

public enum Demand: Equatable, Sendable {
    case more
    case done
}

public enum Completion: Sendable {
    case failure(Error)
    case finished
}

public struct Publisher<Output: Sendable> {
    public enum Error: Swift.Error, CaseIterable, Equatable, Sendable {
        case cancelled
        case internalError
    }

    private let call: (
        UnsafeContinuation<Void, Never>?,
        @escaping (AsyncStream<Output>.Result) async throws -> Demand
    ) -> Task<Demand, Swift.Error>

    internal init(
        _ call: @escaping (
            UnsafeContinuation<Void, Never>?,
            @escaping (AsyncStream<Output>.Result) async throws -> Demand
        ) -> Task<Demand, Swift.Error>
    ) {
        self.call = call
    }
}

public extension Publisher {
    @discardableResult
    func sink(
        onStartup: UnsafeContinuation<Void, Never>?,
        _ f: @escaping (AsyncStream<Output>.Result) async throws -> Demand
    ) -> Task<Demand, Swift.Error> {
        self(onStartup: onStartup, f)
    }

    @discardableResult
    func callAsFunction(
        onStartup: UnsafeContinuation<Void, Never>?,
        _ f: @escaping (AsyncStream<Output>.Result) async throws -> Demand
    ) -> Task<Demand, Swift.Error> {
        call(onStartup, { result in
            guard !Task.isCancelled else { return .done }
            let demand = try await f(result)
            await Task.yield()
            return demand
        })
    }

    @discardableResult
    func sink(
        _ f: @escaping (AsyncStream<Output>.Result) async throws -> Demand
    ) async -> Task<Demand, Swift.Error> {
        await self(f)
    }

    @discardableResult
    func callAsFunction(
        _ f: @escaping (AsyncStream<Output>.Result) async throws -> Demand
    ) async -> Task<Demand, Swift.Error> {
        var t: Task<Demand, Swift.Error>! = .none
        await withUnsafeContinuation { continuation in
            t = call(continuation, { result in
                guard !Task.isCancelled else { return .done }
                let demand = try await f(result)
                await Task.yield()
                return demand
            })
        }
        return t
    }
}

extension Publisher {
    private func lift(
        _ receiveValue: @escaping (Output) async throws -> Void
    ) -> (AsyncStream<Output>.Result) async throws -> Demand {
        { result in switch result {
            case let .value(value):
                try await receiveValue(value)
                return .more
            case .failure, .terminated:
                return .done
        }  }
    }

    func sink(
        onStartup: UnsafeContinuation<Void, Never>?,
        receiveValue: @escaping (Output) async throws -> Void
    ) -> Task<Demand, Swift.Error> {
        sink(onStartup: onStartup, lift(receiveValue))
    }

    func sink(
        receiveValue: @escaping (Output) async throws -> Void
    ) async -> Task<Demand, Swift.Error> {
        await sink(lift(receiveValue))
    }

    private func lift(
        _ receiveCompletion: @escaping (Completion) async throws -> Void,
        _ receiveValue: @escaping (Output) async throws -> Void
    ) -> (AsyncStream<Output>.Result) async throws -> Demand {
        { result in switch result {
            case let .value(value):
                try await receiveValue(value)
                return .more
            case let .failure(error):
                try await receiveCompletion(.failure(error))
                return .done
            case .terminated:
                try await receiveCompletion(.finished)
                return .done
        } }
    }

    func sink(
        onStartup: UnsafeContinuation<Void, Never>?,
        receiveCompletion: @escaping (Completion) async -> Void,
        receiveValue: @escaping (Output) async -> Void
    ) -> Task<Demand, Swift.Error> {
        sink(onStartup: onStartup, lift(receiveCompletion, receiveValue))
    }

    func sink(
        receiveCompletion: @escaping (Completion) async -> Void,
        receiveValue: @escaping (Output) async -> Void
    ) async -> Task<Demand, Swift.Error> {
        await sink(lift(receiveCompletion, receiveValue))
    }
}
