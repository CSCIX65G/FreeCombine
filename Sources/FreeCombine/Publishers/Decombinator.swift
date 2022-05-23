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
                let innerTask: Cancellable<Demand> = try await withUnsafeThrowingContinuation { demandContinuation in
                    let enqueueStatus = stateTask.send(.subscribe(downstream, continuation, demandContinuation))
                    guard case .enqueued = enqueueStatus else {
                        return demandContinuation.resume(throwing: PublisherError.enqueueError)
                    }
                }
                let cancellation: @Sendable () -> Void = {
                    innerTask.cancel()
                    onCancel()
                }
                return try await withTaskCancellationHandler(handler: cancellation) {
                    switch await innerTask.task.result {
                        case let .failure(error):
                            if let error = error as? StateTaskError,
                                case error = StateTaskError.cancelled { cancellation() }
                            throw error
                        case let .success(value):
                            return value
                    }
                }
            }
        }
    }
}
