//
//  Autoconnect.swift
//  
//
//  Created by Van Simmons on 6/7/22.
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
    func autoconnect(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line,
        deinitBehavior: DeinitBehavior = .assert,
        buffering: AsyncStream<ConnectableRepeaterState<Output>.Action>.Continuation.BufferingPolicy = .bufferingOldest(1)
    ) async throws -> Self {
        let connectable: Connectable<Output> = try await self.makeConnectable(buffering: buffering)
        let cancellableRef: ValueRef<Cancellable<Demand>?> = .init(value: .none)
        return .init { continuation, downstream in
            Cancellable<Cancellable<Demand>>.join(.init {
                let cancellable = await connectable.publisher().sink(downstream)
                let refValue: Cancellable<Demand>! = cancellableRef.value
                if refValue == nil {
                    do {
                        Task {
                            _ = await connectable.result
                            _ = await cancellable.result
                            try cancellableRef.set(value: .none)
                        }
                        try await connectable.connect()
                        try cancellableRef.set(value: cancellable)
                    } catch {
//                        _ = try? await downstream(.completion(.finished))
                        continuation.resume()
                        _ = try await connectable.cancelAndAwaitResult()
                    }
                }
                continuation.resume()
                return cancellable
            } )
        }
    }
}
