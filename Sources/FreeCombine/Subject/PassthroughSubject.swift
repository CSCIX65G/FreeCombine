//
//  PassthroughSubject.swift
//  
//
//  Created by Van Simmons on 5/11/22.
//
public func PassthroughSubject<Output>(
    _ type: Output.Type = Output.self,
    buffering: AsyncStream<DistributorState<Output>.Action>.Continuation.BufferingPolicy = .bufferingOldest(1),
    onStartup: Resumption<Void>
) -> StateTask<DistributorState<Output>, DistributorState<Output>.Action> {
    Channel.init(buffering: buffering)
    .stateTask(
        initialState: { channel in .init(currentValue: .none, nextKey: 0, downstreams: [:]) },
        onStartup: onStartup,
        reducer: Reducer(
            onCompletion: DistributorState<Output>.complete,
            disposer: DistributorState<Output>.dispose,
            reducer: DistributorState<Output>.reduce
        )
    )
}

public func PassthroughSubject<Output>(
    _ type: Output.Type = Output.self,
    buffering: AsyncStream<DistributorState<Output>.Action>.Continuation.BufferingPolicy = .bufferingOldest(1)
) async -> StateTask<DistributorState<Output>, DistributorState<Output>.Action> {
    try! await Channel(buffering: buffering)
        .stateTask(
            initialState: { channel in .init(currentValue: .none, nextKey: 0, downstreams: [:]) },
            reducer: Reducer(
                onCompletion: DistributorState<Output>.complete,
                disposer: DistributorState<Output>.dispose,
                reducer: DistributorState<Output>.reduce
            )
        )
}
