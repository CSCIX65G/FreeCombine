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
            let t: Task<Cancellable<Demand>, Swift.Error> = .init {
                let c: Cancellable<Demand> = try await withUnsafeThrowingContinuation { demandContinuation in
                    let enqueueStatus = stateTask.send(.subscribe(downstream, demandContinuation))
                    guard case .enqueued = enqueueStatus else {
                        return demandContinuation.resume(throwing: PublisherError.enqueueError)
                    }
                }
                continuation?.resume()
                return c
            }
            return .init(
                cancel: { Task {
                    await t.result.map {
                        $0.cancel()
                    }
                } },
                isCancelled: { t.isCancelled },
                value: {
                    let cancellable = try await t.value
                    let value = try await cancellable.value
                    return value
                },
                result: {
                    let r = await t.result
                    switch r {
                        case let .success(result):  return await result.result
                        case let .failure(error): return .failure(error)
                    }
                }
            )
        }
    }
}
