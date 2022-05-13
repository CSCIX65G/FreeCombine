//
//  Subject.swift
//  
//
//  Created by Van Simmons on 3/22/22.
//

public extension StateTask  {
    static func stateTask<Output>(
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
                .init(channel: channel, currentValue: currentValue, nextKey: 0, downstreams: [:])
            },
            buffering: buffering,
            onCancel: onCancel,
            onCompletion: onCompletion,
            reducer: DistributorState<Output>.reduce
        )
    }

    convenience init<Output>(
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
                .init(channel: channel, currentValue: currentValue, nextKey: 0, downstreams: [:])
            },
            buffering: buffering,
            onStartup: onStartup,
            onCancel: onCancel,
            onCompletion: onCompletion,
            reducer: DistributorState<Output>.reduce
        )
    }

    func send<Output>(_ value: Output) async throws -> Void where Action == DistributorState<Output>.Action {
        let _: Void = try await withUnsafeThrowingContinuation { continuation in
            let enqueueResult = yield(.receive(.value(value), continuation))
            guard case .enqueued = enqueueResult else {
                continuation.resume(throwing: Self.Error.enqueueError(enqueueResult))
                return
            }
            continuation.resume()
        }
    }
}

public func CurrentValueSubject<Output>(
    currentValue: Output,
    buffering: AsyncStream<DistributorState<Output>.Action>.Continuation.BufferingPolicy = .bufferingOldest(1),
    onStartup: UnsafeContinuation<Void, Never>? = .none,
    onCancel: @escaping () -> Void = { },
    onCompletion: @escaping (
        DistributorState<Output>,
        StateTask<DistributorState<Output>, DistributorState<Output>.Action>.Completion
    ) -> Void = { _, _ in }
) -> StateTask<DistributorState<Output>, DistributorState<Output>.Action> {
    .init(
        currentValue: currentValue,
        buffering: buffering,
        onStartup: onStartup,
        onCancel: onCancel,
        onCompletion: onCompletion
    )
}

public func CurrentValueSubject<Output>(
    currentValue: Output,
    buffering: AsyncStream<DistributorState<Output>.Action>.Continuation.BufferingPolicy = .bufferingOldest(1),
    onCancel: @escaping () -> Void = { },
    onCompletion: @escaping (
        DistributorState<Output>,
        StateTask<DistributorState<Output>, DistributorState<Output>.Action>.Completion
    ) -> Void = { _, _ in }
) async -> StateTask<DistributorState<Output>, DistributorState<Output>.Action> {
    await .stateTask(
        currentValue: currentValue,
        buffering: buffering,
        onCancel: onCancel,
        onCompletion: onCompletion
    )
}
