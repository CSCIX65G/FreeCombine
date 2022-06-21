//
//  StateTask+DistributorState.swift
//  
//
//  Created by Van Simmons on 5/13/22.
//

/* where State == DistributorState<Output>, Action == DistributorState<Output>.Action */
public extension StateTask {
    @inlinable
    func send<Output: Sendable>(
        _ value: Output
    ) async throws -> Void where State == DistributorState<Output>, Action == DistributorState<Output>.Action {
        try await send(.value(value))
    }

    @inlinable
    func nonBlockingSend<Output: Sendable>(
        _ value: Output
    ) throws -> Void where State == DistributorState<Output>, Action == DistributorState<Output>.Action {
        try send(.value(value))
    }

    func finish<Output: Sendable>(
    ) async throws -> Void where State == DistributorState<Output>, Action == DistributorState<Output>.Action {
        try await send(.completion(.finished))
        channel.finish()
    }

    func nonBlockingFinish<Output: Sendable>(
    ) throws -> Void where State == DistributorState<Output>, Action == DistributorState<Output>.Action {
        try send(.completion(.finished))
        channel.finish()
    }

    func cancel<Output: Sendable>(
    ) async throws -> Void where State == DistributorState<Output>, Action == DistributorState<Output>.Action {
        try await send(.completion(.cancelled))
        channel.finish()
    }

    func nonBlockingCancel<Output: Sendable>(
    ) throws -> Void where State == DistributorState<Output>, Action == DistributorState<Output>.Action {
        try send(.completion(.cancelled))
        channel.finish()
    }

    @inlinable
    func fail<Output: Sendable>(
        _ error: Error
    ) async throws -> Void where State == DistributorState<Output>, Action == DistributorState<Output>.Action {
        try await send(.completion(.failure(error)))
    }

    @inlinable
    func nonBlockingFail<Output: Sendable>(
        _ error: Error
    ) throws -> Void where State == DistributorState<Output>, Action == DistributorState<Output>.Action {
        try send(.completion(.failure(error)))
    }

    func send<Output: Sendable>(
        _ result: AsyncStream<Output>.Result
    ) async throws -> Void where State == DistributorState<Output>, Action == DistributorState<Output>.Action {
        var enqueueResult: AsyncStream<DistributorState<Output>.Action>.Continuation.YieldResult!
        let _: Void = try await withResumption { resumption in
            enqueueResult = send(.receive(result, resumption))
            guard case .enqueued = enqueueResult else {
                resumption.resume(throwing: PublisherError.cancelled)
                return
            }
        }
        guard case .enqueued = enqueueResult else {
            throw PublisherError.enqueueError
        }
    }

    func send<Output: Sendable>(
        _ result: AsyncStream<Output>.Result
    ) throws -> Void where State == DistributorState<Output>, Action == DistributorState<Output>.Action {
        var enqueueResult: AsyncStream<DistributorState<Output>.Action>.Continuation.YieldResult!
        enqueueResult = send(.receive(result, .none))
        guard case .enqueued = enqueueResult else {
            throw PublisherError.enqueueError
        }
    }
}
