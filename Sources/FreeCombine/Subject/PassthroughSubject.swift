//
//  PassthroughSubject.swift
//  
//
//  Created by Van Simmons on 5/11/22.
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
public func PassthroughSubject<Output>(
    function: StaticString = #function,
    file: StaticString = #file,
    line: UInt = #line,
    _ type: Output.Type = Output.self,
    buffering: AsyncStream<DistributorReceiveState<Output>.Action>.Continuation.BufferingPolicy = .bufferingOldest(1),
    onStartup: Resumption<Void>
) async throws -> Subject<Output> {
    try await .init(
        buffering: buffering,
        stateTask: Channel.init(buffering: .unbounded) .stateTask(
            function: function,
            file: file,
            line: line,
            onStartup: onStartup,
            initialState: { channel in .init(currentValue: .none, nextKey: 0, downstreams: [:]) },
            reducer: Reducer(
                reducer: DistributorState<Output>.reduce,
                disposer: DistributorState<Output>.dispose,
                finalizer: DistributorState<Output>.complete
            )
        )
    )
}

public func PassthroughSubject<Output>(
    function: StaticString = #function,
    file: StaticString = #file,
    line: UInt = #line,
    _ type: Output.Type = Output.self,
    buffering: AsyncStream<DistributorReceiveState<Output>.Action>.Continuation.BufferingPolicy = .bufferingOldest(1)
) async throws -> Subject<Output> {
    try await .init(
        buffering: buffering,
        stateTask: try await Channel(buffering: .unbounded).stateTask(
            function: function,
            file: file,
            line: line,
            initialState: { channel in .init(currentValue: .none, nextKey: 0, downstreams: [:]) },
            reducer: Reducer(
                reducer: DistributorState<Output>.reduce,
                disposer: DistributorState<Output>.dispose,
                finalizer: DistributorState<Output>.complete
            )
        )
    )
}
