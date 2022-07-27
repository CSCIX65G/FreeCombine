//
//  StateTask+PromiseState.swift
//
//
//  Created by Van Simmons on 5/13/22.
//

/* where State == PromiseState<Output>, Action == PromiseState<Output>.Action */
public extension StateTask {
    @inlinable
    func send<Output: Sendable>(
        file: StaticString = #file,
        line: UInt = #line,
        deinitBehavior: DeinitBehavior = .assert,
        _ value: Output
    ) async throws -> Void where State == PromiseState<Output>, Action == PromiseState<Output>.Action {
        try await send(
            file: file,
            line: line,
            deinitBehavior: deinitBehavior,
            .success(value)
        )
    }

    @discardableResult
    func send<Output: Sendable>(
        file: StaticString = #file,
        line: UInt = #line,
        deinitBehavior: DeinitBehavior = .assert,
        _ result: Result<Output, Swift.Error>
    ) async throws -> Int where State == PromiseState<Output>, Action == PromiseState<Output>.Action {
        var enqueueResult: AsyncStream<PromiseState<Output>.Action>.Continuation.YieldResult!
        let subscribers: Int = try await withResumption(file: file, line: line, deinitBehavior: deinitBehavior) { resumption in
            enqueueResult = send(.receive(result, resumption))
            guard case .enqueued = enqueueResult else {
                resumption.resume(throwing: PublisherError.enqueueError)
                return
            }
        }
        guard case .enqueued = enqueueResult else {
            throw PublisherError.enqueueError
        }
        return subscribers
    }

    func succeed<Output: Sendable>(
        _ value: Output
    ) async throws -> Void where State == PromiseState<Output>, Action == PromiseState<Output>.Action {
        try await send(.success(value))
    }

    func cancel<Output: Sendable>(
    ) async throws -> Void where State == PromiseState<Output>, Action == PromiseState<Output>.Action {
        try await send(.failure(PublisherError.cancelled))
    }

    @inlinable
    func fail<Output: Sendable>(
        _ error: Error
    ) async throws -> Void where State == PromiseState<Output>, Action == PromiseState<Output>.Action {
        try await send(.failure(error))
    }
}
