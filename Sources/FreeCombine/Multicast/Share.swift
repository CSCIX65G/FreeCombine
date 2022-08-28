//
//  Share.swift
//  
//
//  Created by Van Simmons on 6/26/22.
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
public extension Publisher {
    func share(
        buffering: AsyncStream<DistributorState<Output>.Action>.Continuation.BufferingPolicy = .bufferingOldest(1)
    ) async throws -> Self {
        let subject: Subject<Output> = try await PassthroughSubject()
        let cancellableRef: ValueRef<Cancellable<Demand>?> = .init(value: .none)
        return .init { resumption, downstream in
            Cancellable<Cancellable<Demand>>.join(.init {
                let cancellable = await subject.publisher().sink(downstream)
                var i1: Cancellable<Demand>! = cancellableRef.value
                if i1 == nil {
                    i1 = await self.sink({ result in
                        do {
                            switch result {
                                case .value(let value):
                                    try await subject.blockingSend(value)
                                    return .more
                                case .completion(.finished), .completion(.cancelled):
                                    try await subject.blockingSend(result)
                                    return .done
                                case .completion(.failure(let error)):
                                    try await subject.blockingSend(result)
                                    throw error
                            }
                        } catch {
                            _ = await cancellable.cancelAndAwaitResult()
                            _ = await subject.result;
                            throw error
                        }
                    })
                    let i2: Cancellable<Demand> = i1
                    Task {
                        _ = await cancellable.result
                        _ = await subject.result;
                        _ = await i2.result;
                        cancellableRef.set(value: .none)
                    }
                    cancellableRef.set(value: i1)
                }
                resumption.resume()
                return cancellable
            } )
        }
    }
}

