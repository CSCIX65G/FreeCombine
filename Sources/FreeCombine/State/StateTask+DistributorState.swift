//
//  StateTask+DistributorState.swift
//  
//
//  Created by Van Simmons on 5/13/22.
//
public extension StateTask {
    func send<Output: Sendable>(
        _ value: Output
    ) async throws -> Void where Action == DistributorState<Output>.Action {
        var enqueueResult: AsyncStream<DistributorState<Output>.Action>.Continuation.YieldResult!
        let _: Void = await withUnsafeContinuation { continuation in
            enqueueResult = yield(.receive(.value(value), continuation))
            guard case .enqueued = enqueueResult else { continuation.resume(); return }
        }
        guard case .enqueued = enqueueResult else {
            throw Self.Error.enqueueError(enqueueResult)
        }
    }

    func send<Output: Sendable>(
        _ result: AsyncStream<Output>.Result
    ) async throws -> Void where Action == DistributorState<Output>.Action {
        var enqueueResult: AsyncStream<DistributorState<Output>.Action>.Continuation.YieldResult!
        let _: Void = await withUnsafeContinuation { continuation in
            enqueueResult = yield(.receive(result, continuation))
            guard case .enqueued = enqueueResult else { continuation.resume(); return }
        }
        guard case .enqueued = enqueueResult else {
            throw Self.Error.enqueueError(enqueueResult)
        }
    }

    func complete<Output: Sendable>() async throws -> Void where Action == DistributorState<Output>.Action {
        var enqueueResult: AsyncStream<DistributorState<Output>.Action>.Continuation.YieldResult!
        let _: Void = await withUnsafeContinuation { continuation in
            enqueueResult = yield(.receive(.completion(.finished), continuation))
            guard case .enqueued = enqueueResult else { continuation.resume(); return }
        }
        guard case .enqueued = enqueueResult else {
            throw Self.Error.enqueueError(enqueueResult)
        }
    }

    func fail<Output: Sendable>(
        _ error: Error
    ) async throws -> Void where Action == DistributorState<Output>.Action {
        var enqueueResult: AsyncStream<DistributorState<Output>.Action>.Continuation.YieldResult!
        let _: Void = await withUnsafeContinuation { continuation in
            enqueueResult = yield(.receive(.completion(.failure(error)), continuation))
            guard case .enqueued = enqueueResult else { continuation.resume(); return }
        }
        guard case .enqueued = enqueueResult else {
            throw Self.Error.enqueueError(enqueueResult)
        }
    }
}

public extension StateTask  {
    static func stateTask<Output: Sendable>(
        currentValue: Output,
        buffering: AsyncStream<DistributorState<Output>.Action>.Continuation.BufferingPolicy = .bufferingOldest(1),
        onCancel: @escaping () -> Void = { },
        onCompletion: @escaping (
            DistributorState<Output>,
            StateTask<DistributorState<Output>, DistributorState<Output>.Action>.Completion
        ) -> Void = { _, _ in }
    ) async -> Self where State == DistributorState<Output>, Action == DistributorState<Output>.Action {
        await .stateTask(
            initialState: { channel in
                .init(currentValue: currentValue, nextKey: 0, downstreams: [:])
            },
            buffering: buffering,
            onCancel: onCancel,
            onCompletion: onCompletion,
            reducer: DistributorState<Output>.reduce
        )
    }

    convenience init<Output: Sendable>(
        currentValue: Output,
        buffering: AsyncStream<DistributorState<Output>.Action>.Continuation.BufferingPolicy = .bufferingOldest(1),
        onStartup: UnsafeContinuation<Void, Never>? = .none,
        onCancel: @escaping () -> Void = { },
        onCompletion: @escaping (
            DistributorState<Output>,
            StateTask<DistributorState<Output>, DistributorState<Output>.Action>.Completion
        ) -> Void = { _, _ in }
    ) where State == DistributorState<Output>, Action == DistributorState<Output>.Action {
        self.init(
            initialState: { channel in
                .init(currentValue: currentValue, nextKey: 0, downstreams: [:])
            },
            buffering: buffering,
            onStartup: onStartup,
            onCancel: onCancel,
            onCompletion: onCompletion,
            reducer: DistributorState<Output>.reduce
        )
    }
}
