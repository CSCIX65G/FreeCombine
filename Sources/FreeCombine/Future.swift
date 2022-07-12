//
//  Future.swift
//  
//
//  Created by Van Simmons on 7/10/22.
//
public enum FutureError: Swift.Error, Sendable, CaseIterable {
    case cancelled
    case internalError
}

public struct Future<Output: Sendable>: Sendable {
    private let call: @Sendable (
        Resumption<Void>,
        @Sendable @escaping (Result<Output, Swift.Error>) async throws -> Void
    ) -> Cancellable<Void>

    internal init(
        _ call: @Sendable @escaping (
            Resumption<Void>,
            @Sendable @escaping (Result<Output, Swift.Error>) async throws -> Void
        ) -> Cancellable<Void>
    ) {
        self.call = call
    }
}

public extension Future {
    @discardableResult
    func sink(
        onStartup: Resumption<Void>,
        _ f: @Sendable @escaping (Result<Output, Swift.Error>) async throws -> Void
    ) -> Cancellable<Void> {
        self(onStartup: onStartup, f)
    }

    @discardableResult
    func callAsFunction(
        onStartup: Resumption<Void>,
        _ downstream: @Sendable @escaping (Result<Output, Swift.Error>) async throws -> Void
    ) -> Cancellable<Void> {
        call(onStartup, { result in
            guard !Task.isCancelled else {
                return try await handleFutureCancellation(of: downstream)
            }
            return try await downstream(result)
        } )
    }

    @discardableResult
    func sink(
        file: StaticString = #file,
        line: UInt = #line,
        deinitBehavior: DeinitBehavior = .assert,
        _ f: @Sendable @escaping (Result<Output, Swift.Error>) async throws -> Void
    ) async -> Cancellable<Void> {
        await self(file: file, line: line, deinitBehavior: deinitBehavior, f)
    }

    @discardableResult
    func callAsFunction(
        file: StaticString = #file,
        line: UInt = #line,
        deinitBehavior: DeinitBehavior = .assert,
        _ f: @Sendable @escaping (Result<Output, Swift.Error>) async throws -> Void
    ) async -> Cancellable<Void> {
        var cancellable: Cancellable<Void>!
        let _: Void = try! await withResumption(file: file, line: line, deinitBehavior: deinitBehavior) { continuation in
            cancellable = self(onStartup: continuation, f)
        }
        return cancellable
    }
}

extension Future {
    @Sendable private func lift(
        _ receiveFailure: @Sendable @escaping (Swift.Error) async throws -> Void,
        _ receiveValue: @Sendable @escaping (Output) async throws -> Void
    ) -> @Sendable (Result<Output, Swift.Error>) async throws -> Void {
        { result in switch result {
            case let .success(value):
                return try await receiveValue(value)
            case let .failure(error):
                do { return try await receiveFailure(error) }
                catch { throw error }
        } }
    }

    func sink(
        onStartup: Resumption<Void>,
        receiveValue: @Sendable @escaping (Output) async throws -> Void
    ) -> Cancellable<Void> {
        sink(onStartup: onStartup, receiveCompletion: void, receiveValue: receiveValue)
    }

    func sink(
        receiveValue: @Sendable @escaping (Output) async throws -> Void
    ) async -> Cancellable<Void> {
        await sink(receiveCompletion: void, receiveValue: receiveValue)
    }

    func sink(
        onStartup: Resumption<Void>,
        receiveCompletion: @Sendable @escaping (Swift.Error) async throws -> Void,
        receiveValue: @Sendable @escaping (Output) async throws -> Void
    ) -> Cancellable<Void> {
        sink(onStartup: onStartup, lift(receiveCompletion, receiveValue))
    }

    func sink(
        receiveCompletion: @Sendable @escaping (Swift.Error) async throws -> Void,
        receiveValue: @Sendable @escaping (Output) async throws -> Void
    ) async -> Cancellable<Void> {
        await sink(lift(receiveCompletion, receiveValue))
    }
}

func handleFutureCancellation<Output>(
    of f: @Sendable @escaping (Result<Output, Swift.Error>) async throws -> Void
) async throws -> Void {
    _ = try await f(.failure(FutureError.cancelled))
}
