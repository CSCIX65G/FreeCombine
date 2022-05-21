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
    func finish<Output: Sendable>() async throws -> Void where State == DistributorState<Output>, Action == DistributorState<Output>.Action {
        try await send(.completion(.finished))
    }

    @inlinable
    func fail<Output: Sendable>(
        _ error: Error
    ) async throws -> Void where State == DistributorState<Output>, Action == DistributorState<Output>.Action {
        try await send(.completion(.failure(error)))
    }

    func send<Output: Sendable>(
        _ result: AsyncStream<Output>.Result
    ) async throws -> Void where State == DistributorState<Output>, Action == DistributorState<Output>.Action {
        var enqueueResult: AsyncStream<DistributorState<Output>.Action>.Continuation.YieldResult!
        let _: Void = await withUnsafeContinuation { continuation in
            enqueueResult = send(.receive(result, continuation))
            guard case .enqueued = enqueueResult else { continuation.resume(); return }
        }
        guard case .enqueued = enqueueResult else {
            throw PublisherError.enqueueError
        }
    }

    static func stateTask<Output: Sendable>(
        currentValue: Output,
        buffering: AsyncStream<DistributorState<Output>.Action>.Continuation.BufferingPolicy = .bufferingOldest(1),
        onCancel: @Sendable @escaping () -> Void = { },
        onCompletion: @escaping (
            inout DistributorState<Output>,
            StateTask<DistributorState<Output>, DistributorState<Output>.Action>.Completion
        ) async -> Void = { _, _ in },
        disposer: @escaping (Action, Error) -> Void = { _, _ in }
    ) async -> Self where State == DistributorState<Output>, Action == DistributorState<Output>.Action {
        await .stateTask(
            initialState: { channel in
                .init(channel: channel, currentValue: currentValue, nextKey: 0, downstreams: [:])
            },
            buffering: buffering,
            onCancel: onCancel,
            onCompletion: onCompletion,
            disposer: disposer,
            reducer: DistributorState<Output>.reduce
        )
    }

    convenience init<Output: Sendable>(
        currentValue: Output,
        buffering: AsyncStream<DistributorState<Output>.Action>.Continuation.BufferingPolicy = .bufferingOldest(1),
        onStartup: UnsafeContinuation<Void, Never>? = .none,
        onCancel: @Sendable @escaping () -> Void = { },
        onCompletion: @escaping (
            inout DistributorState<Output>,
            StateTask<DistributorState<Output>, DistributorState<Output>.Action>.Completion
        ) async -> Void = { _, _ in }
    ) where State == DistributorState<Output>, Action == DistributorState<Output>.Action {
        self.init(
            initialState: { channel in
                .init(channel: channel, currentValue: currentValue, nextKey: 0, downstreams: [:])
            },
            buffering: buffering,
            onStartup: onStartup,
            onCancel: onCancel,
            onCompletion: onCompletion,
            reducer: DistributorState<Output>.reduce
        )
    }
}
