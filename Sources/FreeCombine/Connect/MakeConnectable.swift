//
//  MakeConnectable.swift
//  
//
//  Created by Van Simmons on 6/4/22.
//
public extension Publisher {
    func makeConnectable(
        buffering: AsyncStream<ConnectableState<Output>.Action>.Continuation.BufferingPolicy = .bufferingOldest(1)
    ) async -> Connectable<Output> {
        try! await .init(
            stateTask: Channel(buffering: buffering).stateTask(
                initialState: ConnectableState<Output>.create(upstream: self),
                reducer: Reducer(
                    onCompletion: ConnectableState<Output>.complete,
                    disposer: ConnectableState<Output>.dispose,
                    reducer: ConnectableState<Output>.reduce
                )
            )
        )
    }
}
