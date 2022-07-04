//
//  MakeConnectable.swift
//  
//
//  Created by Van Simmons on 6/4/22.
//
public extension Publisher {
    func makeConnectable(
        file: StaticString = #file,
        line: UInt = #line,
        deinitBehavior: DeinitBehavior = .assert,
        buffering: AsyncStream<RepeatDistributeState<Output>.Action>.Continuation.BufferingPolicy = .bufferingOldest(1)
    ) async throws -> Connectable<Output> {
        let repeater: Channel<RepeatDistributeState<Output>.Action> = .init(buffering: buffering)
        return try await .init(
            file: file,
            line: line,
            deinitBehavior: deinitBehavior,
            repeater: repeater,
            stateTask: Channel(buffering: .unbounded).stateTask(
                initialState: ConnectableState<Output>.create(upstream: self, repeater: repeater),
                reducer: Reducer(
                    onCompletion: ConnectableState<Output>.complete,
                    disposer: ConnectableState<Output>.dispose,
                    reducer: ConnectableState<Output>.reduce
                )
            )
        )
    }
}
