//
//  Decombinator.swift
//  
//
//  Created by Van Simmons on 5/15/22.
//
//  Copyright 2022, ComputeCycles, LLC
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
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
        function: StaticString = #function,
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
        function: StaticString = #function,
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

public func Decombinator<Output>(
    stateTask: StateTask<PromiseState<Output>, PromiseState<Output>.Action>
) -> Future<Output> {
    .init(stateTask: stateTask)
}

public extension Future {
    init(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line,
        deinitBehavior: DeinitBehavior = .assert,
        stateTask: StateTask<PromiseState<Output>, PromiseState<Output>.Action>
    ) {
        self = .init { continuation, downstream in
            Cancellable<Cancellable<Void>>.join(.init {
                var enqueueStatus: AsyncStream<PromiseState<Output>.Action>.Continuation.YieldResult!
                let c: Cancellable<Void> = try await withResumption(
                    file: file,
                    line: line,
                    deinitBehavior: deinitBehavior
                ) { voidResumption in
                    enqueueStatus = stateTask.send(.subscribe(downstream, voidResumption))
                    guard case .enqueued = enqueueStatus else {
                        voidResumption.resume(throwing: PublisherError.enqueueError)
                        return
                    }
                }
                guard case .enqueued = enqueueStatus else {
                    continuation.resume(throwing: PublisherError.enqueueError)
                    return .init { try await downstream(.failure(PublisherError.enqueueError)) }
                }
                continuation.resume()
                return c
            } )
        }
    }
}
