//
//  PassthroughSubject.swift
//  
//
//  Created by Van Simmons on 5/11/22.
//
public func PassthroughSubject<Output>(
    type: Output.Type = Output.self,
    buffering: AsyncStream<DistributorState<Output>.Action>.Continuation.BufferingPolicy = .bufferingOldest(1),
    onStartup: UnsafeContinuation<Void, Never>? = .none,
    onCancel: @Sendable @escaping () -> Void = { },
    onCompletion: @escaping (
        inout DistributorState<Output>,
        StateTask<DistributorState<Output>, DistributorState<Output>.Action>.Completion
    ) async -> Void = { _, _ in }
) -> StateTask<DistributorState<Output>, DistributorState<Output>.Action> {
    .init(
        initialState: DistributorState<Output>.init,
        buffering: buffering,
        onStartup: onStartup,
        onCancel: onCancel,
        onCompletion: onCompletion,
        reducer: DistributorState<Output>.reduce
    )
}

public func PassthroughSubject<Output>(
    type: Output.Type = Output.self,
    buffering: AsyncStream<DistributorState<Output>.Action>.Continuation.BufferingPolicy = .bufferingOldest(1),
    onCancel: @Sendable @escaping () -> Void = { },
    onCompletion: @escaping (
        inout DistributorState<Output>,
        StateTask<DistributorState<Output>, DistributorState<Output>.Action>.Completion
    ) async -> Void = { _, _ in }
) async -> StateTask<DistributorState<Output>, DistributorState<Output>.Action> {
    await .stateTask(
        initialState: DistributorState<Output>.init,
        buffering: buffering,
        onCancel: onCancel,
        onCompletion: onCompletion,
        reducer: DistributorState<Output>.reduce
    )
}
