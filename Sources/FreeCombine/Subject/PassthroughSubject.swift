//
//  PassthroughSubject.swift
//  
//
//  Created by Van Simmons on 5/11/22.
//
public func PassthroughSubject<Output>(
    _ type: Output.Type = Output.self,
    buffering: AsyncStream<DistributorState<Output>.Action>.Continuation.BufferingPolicy = .bufferingOldest(1),
    onStartup: UnsafeContinuation<Void, Never>? = .none,
    onCancel: @Sendable @escaping () -> Void = { }
) -> StateTask<DistributorState<Output>, DistributorState<Output>.Action> {
    Channel.init(buffering: buffering)
    .stateTask(
        initialState: DistributorState<Output>.init,
        onStartup: onStartup,
        onCancel: onCancel,
        reducer: Reducer(
            onCompletion: DistributorState<Output>.complete,
            reducer: DistributorState<Output>.reduce
        )
    )
}

public func PassthroughSubject<Output>(
    _ type: Output.Type = Output.self,
    buffering: AsyncStream<DistributorState<Output>.Action>.Continuation.BufferingPolicy = .bufferingOldest(1),
    onCancel: @Sendable @escaping () -> Void = { }
) async -> StateTask<DistributorState<Output>, DistributorState<Output>.Action> {
    await Channel(buffering: buffering)
        .stateTask(
            initialState: DistributorState<Output>.init,
            onCancel: onCancel,
            reducer: Reducer(
                onCompletion: DistributorState<Output>.complete,
                reducer: DistributorState<Output>.reduce
            )
        )
}
