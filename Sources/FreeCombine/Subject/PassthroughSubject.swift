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
    onCancel: @Sendable @escaping () -> Void = { }
) -> StateTask<DistributorState<Output>, DistributorState<Output>.Action> {
    .init(
        initialState: DistributorState<Output>.init,
        buffering: buffering,
        onStartup: onStartup,
        onCancel: onCancel,
        reducer: Reducer(reducer: DistributorState<Output>.reduce)
    )
}

public func PassthroughSubject<Output>(
    type: Output.Type = Output.self,
    buffering: AsyncStream<DistributorState<Output>.Action>.Continuation.BufferingPolicy = .bufferingOldest(1),
    onCancel: @Sendable @escaping () -> Void = { }
) async -> StateTask<DistributorState<Output>, DistributorState<Output>.Action> {
    await .stateTask(
        initialState: DistributorState<Output>.init,
        buffering: buffering,
        onCancel: onCancel,
        reducer: Reducer(reducer: DistributorState<Output>.reduce)
    )
}
