//
//  Decombinator.swift
//  
//
//  Created by Van Simmons on 5/15/22.
//
public extension StateTask {
    func publisher<Output: Sendable>(
        onCancel: @Sendable @escaping () -> Void = { }
    ) -> Publisher<Output> where State == DistributorState<Output>, Action == DistributorState<Output>.Action {
        .init(onCancel: onCancel, stateTask: self)
    }
}

public func Decombinator<Output>(
    onCancel: @Sendable @escaping () -> Void = { },
    stateTask: StateTask<DistributorState<Output>, DistributorState<Output>.Action>
) -> Publisher<Output> {
    .init(onCancel: onCancel, stateTask: stateTask)
}

public extension Publisher {
    init(
        onCancel: @Sendable @escaping () -> Void = { },
        stateTask: StateTask<DistributorState<Output>, DistributorState<Output>.Action>
    ) {
        self = .init { continuation, downstream in
            .init {
                let innerTask: Task<Demand, Swift.Error> = try await withUnsafeThrowingContinuation { demandContinuation in
                    let enqueueStatus = stateTask.send(.subscribe(downstream, continuation, demandContinuation))
                    guard case .enqueued = enqueueStatus else {
                        demandContinuation.resume(
                            throwing: PublisherError.enqueueError
                        )
                        return
                    }
                }
                let cancellation: @Sendable () -> Void = {
                    innerTask.cancel()
                    onCancel()
                }
                return try await withTaskCancellationHandler(handler: cancellation) {
                    return try await innerTask.value
                }
            }
        }
    }
}
