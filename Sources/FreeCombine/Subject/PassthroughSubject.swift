//
//  PassthroughSubject.swift
//  
//
//  Created by Van Simmons on 5/11/22.
//
public func PassthroughSubject<Output>(
    file: StaticString = #file,
    line: UInt = #line,
    deinitBehavior: DeinitBehavior = .assert,
    _ type: Output.Type = Output.self,
    buffering: AsyncStream<DistributorReceiveState<Output>.Action>.Continuation.BufferingPolicy = .bufferingOldest(1),
    onStartup: Resumption<Void>
) async throws -> Subject<Output> {
    try await .init(
        buffering: buffering,
        stateTask: Channel.init(buffering: .unbounded) .stateTask(
            initialState: { channel in .init(currentValue: .none, nextKey: 0, downstreams: [:]) },
            onStartup: onStartup,
            reducer: Reducer(
                onCompletion: DistributorState<Output>.complete,
                disposer: DistributorState<Output>.dispose,
                reducer: DistributorState<Output>.reduce
            )
        )
    )
}

public func PassthroughSubject<Output>(
    file: StaticString = #file,
    line: UInt = #line,
    deinitBehavior: DeinitBehavior = .assert,
    _ type: Output.Type = Output.self,
    buffering: AsyncStream<DistributorReceiveState<Output>.Action>.Continuation.BufferingPolicy = .bufferingOldest(1)
) async throws -> Subject<Output> {
    try await .init(
        buffering: buffering,
        stateTask: try await Channel(buffering: .unbounded).stateTask(
            file: file,
            line: line,
            deinitBehavior: deinitBehavior,
            initialState: { channel in .init(currentValue: .none, nextKey: 0, downstreams: [:]) },
            reducer: Reducer(
                onCompletion: DistributorState<Output>.complete,
                disposer: DistributorState<Output>.dispose,
                reducer: DistributorState<Output>.reduce
            )
        )
    )
}
