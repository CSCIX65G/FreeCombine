//: [Previous](@previous)

import _Concurrency

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

public struct Publisher<Output: Sendable>: Sendable {
    private let call: @Sendable (
        UnsafeContinuation<Void, Never>?,
        @Sendable @escaping (AsyncStream<Output>.Result) async throws -> Demand
    ) -> Task<Demand, Swift.Error>

    internal init(
        _ call: @Sendable @escaping (
            UnsafeContinuation<Void, Never>?,
            @Sendable @escaping (AsyncStream<Output>.Result) async throws -> Demand
        ) -> Task<Demand, Swift.Error>
    ) {
        self.call = call
    }

    @discardableResult
    func callAsFunction(
        onStartup: UnsafeContinuation<Void, Never>?,
        _ f: @Sendable @escaping (AsyncStream<Output>.Result) async throws -> Demand
    ) -> Task<Demand, Swift.Error> {
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

public extension Publisher {
    func map<B>(
        _ f: @escaping (Output) async -> B
    ) -> Publisher<B> {
        .init { continuation, downstream in self(onStartup: continuation) { r in switch r {
            case .value(let a):
                return try await downstream(.value(f(a)))
            case let .completion(value):
                return try await downstream(.completion(value))
        } } }
    }
    func flatMap<B>(
        _ f: @escaping (Output) async -> Publisher<B>
    ) -> Publisher<B> {
        .init { continuation, downstream in self(onStartup: continuation) { r in switch r {
            case .value(let a):
                return try await f(a)(onStartup: continuation, flattener(downstream)).value
            case let .completion(value):
                return try await downstream(.completion(value))
        } } }
    }
}

//: [Next](@next)
