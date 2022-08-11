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
        @escaping @Sendable (Result<Output, Swift.Error>) async throws -> Void
    ) -> Cancellable<Void>

    internal init(
        _ call: @escaping @Sendable (
            Resumption<Void>,
            @escaping @Sendable (Result<Output, Swift.Error>) async throws -> Void
        ) -> Cancellable<Void>
    ) {
        self.call = call
    }
}

public extension Future {
    @discardableResult
    func sink(
        onStartup: Resumption<Void>,
        _ downstream: @escaping @Sendable (Result<Output, Swift.Error>) async throws -> Void
    ) -> Cancellable<Void> {
        self(onStartup: onStartup, downstream)
    }

    @discardableResult
    func callAsFunction(
        onStartup: Resumption<Void>,
        _ downstream: @escaping @Sendable (Result<Output, Swift.Error>) async throws -> Void
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
        _ downstream: @escaping @Sendable (Result<Output, Swift.Error>) async throws -> Void
    ) async -> Cancellable<Void> {
        await self(file: file, line: line, deinitBehavior: deinitBehavior, downstream)
    }

    @discardableResult
    func callAsFunction(
        file: StaticString = #file,
        line: UInt = #line,
        deinitBehavior: DeinitBehavior = .assert,
        _ downstream: @escaping @Sendable (Result<Output, Swift.Error>) async throws -> Void
    ) async -> Cancellable<Void> {
        var cancellable: Cancellable<Void>!
        let _: Void = try! await withResumption(file: file, line: line, deinitBehavior: deinitBehavior) { continuation in
            cancellable = self(onStartup: continuation, downstream)
        }
        return cancellable
    }
}

func handleFutureCancellation<Output>(
    of downstream: @escaping @Sendable (Result<Output, Swift.Error>) async throws -> Void
) async throws -> Void {
    _ = try await downstream(.failure(FutureError.cancelled))
}
