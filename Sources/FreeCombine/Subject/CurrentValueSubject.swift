//
//  Subject.swift
//  
//
//  Created by Van Simmons on 3/22/22.
//

public func CurrentValueSubject<Output>(
    currentValue: Output,
    buffering: AsyncStream<DistributorState<Output>.Action>.Continuation.BufferingPolicy = .bufferingOldest(1),
    onStartup: UnsafeContinuation<Void, Never>? = .none,
    onCancel: @Sendable @escaping () -> Void = { },
    onCompletion: @escaping (
        inout DistributorState<Output>,
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
    onCancel: @Sendable @escaping () -> Void = { },
    onCompletion: @escaping (
        inout DistributorState<Output>,
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
