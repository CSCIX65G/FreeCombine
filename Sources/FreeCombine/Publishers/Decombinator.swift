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
    ) -> Publisher<Output> where State == ConnectableState<Output>, Action == ConnectableState<Output>.Action {
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
        file: StaticString = #file,
        line: UInt = #line,
        deinitBehavior: DeinitBehavior = .assert,
        stateTask: StateTask<DistributorState<Output>, DistributorState<Output>.Action>
    ) {
        self = .init { continuation, downstream in
            Cancellable<Cancellable<Demand>>.join(.init {
                var enqueueStatus: AsyncStream<DistributorState<Output>.Action>.Continuation.YieldResult!
                let c: Cancellable<Demand> = try await withResumption(
                    file: file,
                    line: line,
                    deinitBehavior: deinitBehavior
                ) { demandResumption in
                    enqueueStatus = stateTask.send(.subscribe(downstream, demandResumption))
                    guard case .enqueued = enqueueStatus else {
                        demandResumption.resume(throwing: PublisherError.enqueueError)
                        return
                    }
                }
                guard case .enqueued = enqueueStatus else {
                    continuation.resume(throwing: PublisherError.enqueueError)
                    return .init { try await downstream(.completion(.finished)) }
                }
                continuation.resume()
                return c
            } )
        }
    }
}

public func Decombinator<Output>(
    stateTask: StateTask<ConnectableState<Output>, ConnectableState<Output>.Action>
) -> Publisher<Output> {
    .init(stateTask: stateTask)
}

public extension Publisher {
    init(
        file: StaticString = #file,
        line: UInt = #line,
        deinitBehavior: DeinitBehavior = .assert,
        stateTask: StateTask<ConnectableState<Output>, ConnectableState<Output>.Action>
    ) {
        self = .init { continuation, downstream in Cancellable<Cancellable<Demand>>.join(.init {
            do {
                let c: Cancellable<Demand> = try await withResumption(
                    file: file,
                    line: line,
                    deinitBehavior: deinitBehavior
                ) { demandResumption in
                    let enqueueStatus = stateTask.send(.distribute(.subscribe(downstream, demandResumption)))
                    guard case .enqueued = enqueueStatus else {
                        demandResumption.resume(throwing: PublisherError.enqueueError)
                        return
                    }
                }
                continuation.resume()
                return c
            } catch {
                let c1 = Cancellable<Demand>.init {
                    switch error {
                        case PublisherError.enqueueError:
                            let returnValue = try await downstream(.completion(.finished))
                            continuation.resume()
                            return returnValue
                        case PublisherError.completed:
                            continuation.resume()
                            return .done
                        default:
                            continuation.resume()
                            throw error
                    }
                }
                return c1
            }
        } ) }
    }
}

