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
    var publisher: Publisher<Output> {
        .init { resumption, downstream in
                .init {
                    let demandRef: ValueRef<Result<Demand, Swift.Error>> = .init(value: .failure(PublisherError.internalError))
                    let innerCancellable = await self.sink { result in
                        do {
                            switch result {
                                case let .success(value):
                                    guard try await downstream(.value(value)) == .more else {
                                        try demandRef.set(value: .success(.done))
                                        return
                                    }
                                    let demand = try await downstream(.completion(.finished))
                                    try demandRef.set(value: .success(demand))
                                case let .failure(error):
                                    switch error {
                                        case FutureError.cancelled:
                                            _ = try await downstream(.completion(.cancelled))
                                            try demandRef.set(value: .failure(PublisherError.cancelled))
                                        default:
                                            _ = try await downstream(.completion(.failure(error)))
                                            try demandRef.set(value: .failure(error))
                                    }
                            }
                        } catch {
                            try demandRef.set(value: .failure(error))
                        }
                    }
                    resumption.resume()
                    _ = await innerCancellable.result
                    return try demandRef.value.get()
                }
        }
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
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line,
        deinitBehavior: DeinitBehavior = .assert,
        _ downstream: @escaping @Sendable (Result<Output, Swift.Error>) async throws -> Void
    ) async -> Cancellable<Void> {
        await self(file: file, line: line, deinitBehavior: deinitBehavior, downstream)
    }

    @discardableResult
    func callAsFunction(
        function: StaticString = #function,
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
