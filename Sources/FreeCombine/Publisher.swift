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
    case cancelled
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
    case completed
    case internalError
    case enqueueError
}

public struct Publisher<Output: Sendable>: Sendable {
    private let call: @Sendable (
        UnsafeContinuation<Void, Never>?,
        @Sendable @escaping (AsyncStream<Output>.Result) async throws -> Demand
    ) -> Cancellable<Demand>

    internal init(
        _ call: @Sendable @escaping (
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
                do { _ = try await f(.completion(.cancelled)) } catch { }
                return .done
            }
            switch result {
                case let .value(value):
                    return try await f(.value(value))
                case let .completion(.failure(error)):
                    return try await f(.completion(.failure(error)))
                case .completion(.finished), .completion(.cancelled):
                    return try await f(result)
            }
        } )
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
        var cancellable: Cancellable<Demand>!
        let _: Void = await withUnsafeContinuation { continuation in
            cancellable = self(onStartup: continuation, f)
        }
        return cancellable
    }
}

extension Publisher {
    @Sendable private func lift(
        _ receiveCompletion: @Sendable @escaping (Completion) async throws -> Void,
        _ receiveValue: @Sendable @escaping (Output) async throws -> Void
    ) -> @Sendable (AsyncStream<Output>.Result) async throws -> Demand {
        { result in switch result {
            case let .value(value):
                try await receiveValue(value)
                return .more
            case let .completion(.failure(error)):
                do { try await receiveCompletion(.failure(error)); return .done }
                catch { throw error }
            case .completion(.finished):
                do { try await receiveCompletion(.finished); return .done }
                catch { return .done }
            case .completion(.cancelled):
                do { try await receiveCompletion(.cancelled); return .done }
                catch { return .done }
        } }
    }

    func sink(
        onStartup: UnsafeContinuation<Void, Never>?,
        receiveValue: @Sendable @escaping (Output) async -> Void
    ) -> Cancellable<Demand> {
        sink(onStartup: onStartup, receiveCompletion: void, receiveValue: receiveValue)
    }

    func sink(
        receiveValue: @Sendable @escaping (Output) async -> Void
    ) async -> Cancellable<Demand> {
        await sink(receiveCompletion: void, receiveValue: receiveValue)
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
        case .value:
            return try await downstream(b)
        case .completion(.failure):
            return try await downstream(b)
        case .completion(.cancelled):
            return try await downstream(b)
    } }
}

func errorFlattener<B>(
    _ downstream: @Sendable @escaping (AsyncStream<B>.Result) async throws -> Demand
) -> @Sendable (AsyncStream<B>.Result) async throws -> Demand {
    { b in switch b {
        case .completion(.finished):
            return .more
        case .value:
            return try await downstream(b)
        case let .completion(.failure(error)):
            throw error
        case .completion(.cancelled):
            return try await downstream(b)
    } }
}

