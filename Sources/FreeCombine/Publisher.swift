//
//  Publisher.swift
//  
//
//  Created by Van Simmons on 3/15/22.
//

public enum Demand: Equatable, Sendable {
    case more
    case done
}

public enum Completion: Sendable {
    case failure(Error)
    case finished
}

public extension AsyncStream where Element: Sendable {
    enum Result: Sendable {
        case value(Element)
        case completion(Completion)
    }
}

public enum PublisherError: Swift.Error, Sendable, CaseIterable {
    case cancelled
    case internalError
    case enqueueError
}

public struct Publisher<Output> {
    private let call: (
        UnsafeContinuation<Void, Never>?,
        @Sendable @escaping (AsyncStream<Output>.Result) async throws -> Demand
    ) -> Cancellable<Demand>

    internal init(
        _ call: @escaping (
            UnsafeContinuation<Void, Never>?,
            @Sendable @escaping (AsyncStream<Output>.Result) async throws -> Demand
        ) -> Cancellable<Demand>
    ) {
        self.call = call
    }
}

public extension Publisher {
    @discardableResult
    func sink(
        onStartup: UnsafeContinuation<Void, Never>?,
        _ f: @Sendable @escaping (AsyncStream<Output>.Result) async throws -> Demand
    ) -> Cancellable<Demand> {
        self(onStartup: onStartup, f)
    }

    @discardableResult
    func callAsFunction(
        onStartup: UnsafeContinuation<Void, Never>?,
        _ f: @Sendable @escaping (AsyncStream<Output>.Result) async throws -> Demand
    ) -> Cancellable<Demand> {
        call(onStartup, { result in
            guard !Task.isCancelled else {
                _ = try await f(.completion(.failure(PublisherError.cancelled)))
                throw PublisherError.cancelled
            }
            let demand = try await f(result)
            return demand
        })
    }

    @discardableResult
    func sink(
        _ f: @Sendable @escaping (AsyncStream<Output>.Result) async throws -> Demand
    ) async -> Cancellable<Demand> {
        await self(f)
    }

    @discardableResult
    func callAsFunction(
        _ f: @Sendable @escaping (AsyncStream<Output>.Result) async throws -> Demand
    ) async -> Cancellable<Demand> {
        var cancellable: Cancellable<Demand>! = .none
        let _: Void = await withUnsafeContinuation { continuation in
            cancellable = call(continuation, { result in
                guard !Task.isCancelled else {
                    _ = try await f(.completion(.failure(PublisherError.cancelled)))
                    throw PublisherError.cancelled
                }
                return try await f(result)
            })
        }
        return cancellable
    }
}

extension Publisher {
    @Sendable private func lift(
        _ receiveValue: @Sendable @escaping (Output) async throws -> Void
    ) -> @Sendable (AsyncStream<Output>.Result) async throws -> Demand {
        { result in switch result {
            case let .value(value):
                try await receiveValue(value)
                return .more
            case .completion:
                return .done
        }  }
    }

    func sink(
        onStartup: UnsafeContinuation<Void, Never>?,
        receiveValue: @Sendable @escaping (Output) async throws -> Void
    ) -> Cancellable<Demand> {
        sink(onStartup: onStartup, lift(receiveValue))
    }

    func sink(
        receiveValue: @Sendable @escaping (Output) async throws -> Void
    ) async -> Cancellable<Demand> {
        await sink(lift(receiveValue))
    }

    @Sendable private func lift(
        _ receiveCompletion: @Sendable @escaping (Completion) async throws -> Void,
        _ receiveValue: @Sendable @escaping (Output) async throws -> Void
    ) -> @Sendable (AsyncStream<Output>.Result) async throws -> Demand {
        { result in switch result {
            case let .value(value):
                try await receiveValue(value)
                return .more
            case let .completion(.failure(error)):
                try await receiveCompletion(.failure(error))
                return .done
            case .completion(.finished):
                try await receiveCompletion(.finished)
                return .done
        } }
    }

    func sink(
        onStartup: UnsafeContinuation<Void, Never>?,
        receiveCompletion: @Sendable @escaping (Completion) async -> Void,
        receiveValue: @Sendable @escaping (Output) async -> Void
    ) -> Cancellable<Demand> {
        sink(onStartup: onStartup, lift(receiveCompletion, receiveValue))
    }

    func sink(
        receiveCompletion: @Sendable @escaping (Completion) async -> Void,
        receiveValue: @Sendable @escaping (Output) async -> Void
    ) async -> Cancellable<Demand> {
        await sink(lift(receiveCompletion, receiveValue))
    }
}

func flattener<B>(
    _ downstream: @Sendable @escaping (AsyncStream<B>.Result) async throws -> Demand
) -> @Sendable (AsyncStream<B>.Result) async throws -> Demand {
    { b in switch b {
        case .completion(.finished):
            return .more
        case .value, .completion(.failure):
            let r = try await downstream(b)
            return r
    } }
}
