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
    onCancel: @escaping () -> Void = { },
    onCompletion: @escaping (
        DistributorState<Output>,
        StateTask<DistributorState<Output>, DistributorState<Output>.Action>.Completion
    ) -> Void = { _, _ in }
) -> StateTask<DistributorState<Output>, DistributorState<Output>.Action> {
    .init(
        initialState: { channel in .init(currentValue: currentValue, nextKey: 0, downstreams: [:]) },
        buffering: buffering,
        onStartup: onStartup,
        onCancel: onCancel,
        onCompletion: onCompletion,
        reducer: DistributorState<Output>.reduce
    )
}
