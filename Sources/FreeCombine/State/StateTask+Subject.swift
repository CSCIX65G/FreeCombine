//
//  StateTask+Subject.swift
//  
//
//  Created by Van Simmons on 5/13/22.
//

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

    func send<Output: Sendable>(_ value: Output) async throws -> Void where Action == DistributorState<Output>.Action {
        var enqueueResult: AsyncStream<DistributorState<Output>.Action>.Continuation.YieldResult!
        let _: Void = await withUnsafeContinuation { continuation in
            enqueueResult = yield(.receive(.value(value), continuation))
            guard case .enqueued = enqueueResult else { continuation.resume(); return }
        }
        guard case .enqueued = enqueueResult else {
            throw Self.Error.enqueueError(enqueueResult)
        }
    }

    func publisher<Output: Sendable>(
        onCancel: @Sendable @escaping () -> Void = { }
    ) -> Publisher<Output> where State == DistributorState<Output>, Action == DistributorState<Output>.Action {
        .init(onCancel: onCancel, stateTask: self)
    }
}

public extension Publisher {
    init(
        onCancel: @Sendable @escaping () -> Void = { },
        stateTask: StateTask<DistributorState<Output>, DistributorState<Output>.Action>
    ) {
        self = .init { continuation, downstream in
            .init {
                let innerTask: Task<Demand, Swift.Error> = try await withUnsafeThrowingContinuation { demandContinuation in
                    let enqueueStatus = stateTask.send(.subscribe(downstream, continuation, demandContinuation))
                    guard case .enqueued = enqueueStatus else {
                        demandContinuation.resume(
                            throwing: StateTask<DistributorState<Output>, DistributorState<Output>.Action>.Error.enqueueError(enqueueStatus)
                        )
                        return
                    }
                }
                let cancellation: @Sendable () -> Void = {
                    innerTask.cancel()
                    onCancel()
                }
                return try await withTaskCancellationHandler(handler: cancellation) {
                    continuation?.resume()
                    return try await innerTask.value
                }
            }
        }
    }
}

