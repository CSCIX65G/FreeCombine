//
//  Decombinator.swift
//  
//
//  Created by Van Simmons on 5/15/22.
//
public extension StateTask {
    func publisher<Output: Sendable>(
    ) -> Publisher<Output> where State == DistributorState<Output>, Action == DistributorState<Output>.Action {
        .init(stateTask: self)
    }

    func publisher<Output: Sendable>(
    ) -> Publisher<Output> where State == MulticasterState<Output>, Action == MulticasterState<Output>.Action {
        .init(stateTask: self)
    }
}

public func Decombinator<Output>(
    stateTask: StateTask<DistributorState<Output>, DistributorState<Output>.Action>
) -> Publisher<Output> {
    .init(stateTask: stateTask)
}

public extension Publisher {
    init(
        stateTask: StateTask<DistributorState<Output>, DistributorState<Output>.Action>
    ) {
        self = .init { continuation, downstream in
            Cancellable<Cancellable<Demand>>.join(.init {
                var enqueueStatus: AsyncStream<DistributorState<Output>.Action>.Continuation.YieldResult!
                let c: Cancellable<Demand> = try await withResumption { demandResumption in
                    enqueueStatus = stateTask.send(.subscribe(downstream, demandResumption))
                    guard case .enqueued = enqueueStatus else {
                        demandResumption.resume(throwing: PublisherError.enqueueError)
                        return
                    }
                }
                continuation?.resume()
                guard case .enqueued = enqueueStatus else {
                    return .init { try await downstream(.completion(.finished)) }
                }
                return c
            } )
        }
    }
}

public func Decombinator<Output>(
    stateTask: StateTask<MulticasterState<Output>, MulticasterState<Output>.Action>
) -> Publisher<Output> {
    .init(stateTask: stateTask)
}

public extension Publisher {
    private enum EnqueueError: Error {
        case enqueueError
    }
    init(
        stateTask: StateTask<MulticasterState<Output>, MulticasterState<Output>.Action>
    ) {
        self = .init { continuation, downstream in Cancellable<Cancellable<Demand>>.join(.init {
            do {
                let c: Cancellable<Demand> = try await withResumption { demandResumption in
                    let enqueueStatus = stateTask.send(.distribute(.subscribe(downstream, demandResumption)))
                    guard case .enqueued = enqueueStatus else {
                        return demandResumption.resume(throwing: EnqueueError.enqueueError)
                    }
                }
                continuation?.resume()
                return c
            } catch {
                let c1 = Cancellable<Demand>.init {
                    switch error {
                        case EnqueueError.enqueueError:
                            let returnValue = try await downstream(.completion(.finished))
                            continuation?.resume()
                            return returnValue
                        case PublisherError.completed:
                            continuation?.resume()
                            return .done
                        default:
                            continuation?.resume()
                            throw error
                    }
                }
                return c1
            }
        } ) }
    }
}
