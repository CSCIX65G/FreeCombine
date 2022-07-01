//
//  MakeConnectable.swift
//  
//
//  Created by Van Simmons on 6/4/22.
//
public extension Publisher {
    func makeConnectable() async -> Connectable<Output> {
        try! await .init(
            stateTask: Channel().stateTask(
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
