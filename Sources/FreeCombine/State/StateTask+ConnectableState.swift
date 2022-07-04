//
//  StateTask+ConnectableState.swift
//
//
//  Created by Van Simmons on 5/13/22.
//

/* where State == ConnectableState<Output>, Action == ConnectableState<Output>.Action */
public extension StateTask {
    @inlinable
    func send<Output: Sendable>(
        file: StaticString = #file,
        line: UInt = #line,
        deinitBehavior: DeinitBehavior = .assert,
        _ value: Output
    ) async throws -> Void where State == ConnectableState<Output>, Action == ConnectableState<Output>.Action {
        try await send(
            file: file,
            line: line,
            deinitBehavior: deinitBehavior,
            .value(value)
        )
    }

    @discardableResult
    func send<Output: Sendable>(
        file: StaticString = #file,
        line: UInt = #line,
        deinitBehavior: DeinitBehavior = .assert,
        _ result: AsyncStream<Output>.Result
    ) async throws -> Int where State == ConnectableState<Output>, Action == ConnectableState<Output>.Action {
        var enqueueResult: AsyncStream<ConnectableState<Output>.Action>.Continuation.YieldResult!
        let subscribers: Int = try await withResumption(file: file, line: line, deinitBehavior: deinitBehavior) { resumption in
            enqueueResult = send(.distribute(.receive(result, resumption)))
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

    func finish<Output: Sendable>(
    ) async throws -> Void where State == ConnectableState<Output>, Action == ConnectableState<Output>.Action {
        try await send(.completion(.finished))
    }

    func cancel<Output: Sendable>(
    ) async throws -> Void where State == ConnectableState<Output>, Action == ConnectableState<Output>.Action {
        try await send(.completion(.cancelled))
    }

    @inlinable
    func fail<Output: Sendable>(
        _ error: Error
    ) async throws -> Void where State == ConnectableState<Output>, Action == ConnectableState<Output>.Action {
        try await send(.completion(.failure(error)))
    }
}