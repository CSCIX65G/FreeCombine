//
//  MakeConnectable.swift
//  
//
//  Created by Van Simmons on 6/4/22.
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
    func makeConnectable(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line,
        deinitBehavior: DeinitBehavior = .assert,
        buffering: AsyncStream<ConnectableRepeaterState<Output>.Action>.Continuation.BufferingPolicy = .bufferingOldest(1)
    ) async throws -> Connectable<Output> {
        let repeater: Channel<ConnectableRepeaterState<Output>.Action> = .init(buffering: buffering)
        return try await .init(
            file: file,
            line: line,
            deinitBehavior: deinitBehavior,
            repeater: repeater,
            stateTask: Channel(buffering: .unbounded).stateTask(
                initialState: ConnectableState<Output>.create(upstream: self, repeater: repeater),
                reducer: Reducer(
                    reducer: ConnectableState<Output>.reduce,
                    disposer: ConnectableState<Output>.dispose,
                    finalizer: ConnectableState<Output>.complete
                )
            )
        )
    }
}
