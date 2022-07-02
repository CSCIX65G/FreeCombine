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
        file: StaticString = #file,
        line: UInt = #line,
        deinitBehavior: DeinitBehavior = .assert,
        _ value: Output
    ) async throws -> Void where State == DistributorState<Output>, Action == DistributorState<Output>.Action {
        try await send(
            file: file,
            line: line,
            deinitBehavior: deinitBehavior,
            .value(value)
        )
    }

    func finish<Output: Sendable>(
    ) async throws -> Void where State == DistributorState<Output>, Action == DistributorState<Output>.Action {
        try await send(.completion(.finished))
        channel.finish()
    }

    func cancel<Output: Sendable>(
    ) async throws -> Void where State == DistributorState<Output>, Action == DistributorState<Output>.Action {
        try await send(.completion(.cancelled))
        channel.finish()
    }

    @inlinable
    func fail<Output: Sendable>(
        _ error: Error
    ) async throws -> Void where State == DistributorState<Output>, Action == DistributorState<Output>.Action {
        try await send(.completion(.failure(error)))
    }

    /*:
     FIXME: This should only drop if send is called from multiple tasks
     but it currently drops if multiple subscriptions enter the queue
     */
    func send<Output: Sendable>(
        file: StaticString = #file,
        line: UInt = #line,
        deinitBehavior: DeinitBehavior = .assert,
        _ result: AsyncStream<Output>.Result
    ) async throws -> Void where State == DistributorState<Output>, Action == DistributorState<Output>.Action {
        var enqueueResult: AsyncStream<DistributorState<Output>.Action>.Continuation.YieldResult!
        let _: Void = try await withResumption(file: file, line: line, deinitBehavior: deinitBehavior) { resumption in
            enqueueResult = send(.receive(result, resumption))
            guard case .enqueued = enqueueResult else {
                resumption.resume(throwing: PublisherError.enqueueError)
                return
            }
        }
        guard case .enqueued = enqueueResult else {
            throw PublisherError.enqueueError
        }
    }
}
