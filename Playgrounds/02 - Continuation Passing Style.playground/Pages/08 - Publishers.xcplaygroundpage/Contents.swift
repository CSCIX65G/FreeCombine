//: [Previous](@previous)

import _Concurrency

public final class Cancellable<Output: Sendable>: Sendable {
    private let _cancel: @Sendable () -> Void
    private let _isCancelled: @Sendable () -> Bool
    private let _value: @Sendable () async throws -> Output
    private let _result: @Sendable () async -> Result<Output, Swift.Error>

    public var isCancelled: Bool {  _isCancelled() }
    public var value: Output {  get async throws { try await _value() } }
    public var result: Result<Output, Swift.Error> {  get async { await _result() } }

    @Sendable public func cancel() -> Void { _cancel() }
    @Sendable public func cancelAndAwaitValue() async throws -> Output {
        _cancel()
        return try await _value()
    }
    @Sendable public func cancelAndAwaitResult() async throws -> Result<Output, Swift.Error> {
        _cancel()
        return await _result()
    }

    init(
        cancel: @escaping @Sendable () -> Void,
        isCancelled: @escaping @Sendable () -> Bool,
        value: @escaping @Sendable () async throws -> Output,
        result: @escaping @Sendable () async -> Result<Output, Swift.Error>
    ) {
        _cancel = cancel
        _isCancelled = isCancelled
        _value = value
        _result = result
    }

    deinit { if !self.isCancelled { self.cancel() } }
}

public extension Cancellable {
    convenience init(task: Task<Output, Swift.Error>) {
        self.init(
            cancel: { task.cancel() },
            isCancelled: { task.isCancelled },
            value: { try await task.value },
            result: { await task.result }
        )
    }
}

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
        @escaping @Sendable (AsyncStream<Output>.Result) async throws -> Demand
    ) -> Cancellable<Demand>

    internal init(
        _ call: @escaping @Sendable (
            UnsafeContinuation<Void, Never>?,
            @escaping @Sendable (AsyncStream<Output>.Result) async throws -> Demand
        ) -> Cancellable<Demand>
    ) {
        self.call = call
    }

    @discardableResult
    func callAsFunction(
        onStartup: UnsafeContinuation<Void, Never>?,
        _ f: @escaping @Sendable (AsyncStream<Output>.Result) async throws -> Demand
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
}

func flattener<B>(
    _ downstream: @escaping @Sendable (AsyncStream<B>.Result) async throws -> Demand
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
        .init { resumption, downstream in self(onStartup: resumption) { r in switch r {
            case .value(let a):
                return try await downstream(.value(f(a)))
            case let .completion(value):
                return try await downstream(.completion(value))
        } } }
    }
    func flatMap<B>(
        _ f: @escaping (Output) async -> Publisher<B>
    ) -> Publisher<B> {
        .init { resumption, downstream in self(onStartup: resumption) { r in switch r {
            case .value(let a):
                return try await f(a)(onStartup: resumption, flattener(downstream)).value
            case let .completion(value):
                return try await downstream(.completion(value))
        } } }
    }
}

Swift.print("C'est finis.")
//: [Next](@next)
