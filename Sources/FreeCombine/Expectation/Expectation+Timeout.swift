//
//  CheckedExpectation+Timeout.swift
//  
//
//  Created by Van Simmons on 2/20/22.
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
public func wait(
    for expectation: Expectation<Void>,
    timeout: UInt64 = .max
) async throws -> Void {
    try await wait(for: [expectation], timeout: timeout, reducing: (), with: {_, _ in })
}

public extension Expectation where Arg == Void {
    func timeout(
        after timeout: UInt64 = .max
    ) async throws -> Void  {
        try await wait(for: self, timeout: timeout)
    }
}

public func wait<FinalResult, PartialResult>(
    for expectation: Expectation<PartialResult>,
    timeout: UInt64 = .max,
    reducing initialValue: FinalResult,
    with reducer: @escaping (inout FinalResult, PartialResult) throws -> Void
) async throws -> FinalResult {
    try await wait(for: [expectation], timeout: timeout, reducing: initialValue, with: reducer)
}

public extension Expectation {
    func timeout<FinalResult>(
        after timeout: UInt64 = .max,
        reducing initialValue: FinalResult,
        with reducer: @escaping (inout FinalResult, Arg) throws -> Void
    ) async throws -> FinalResult  {
        try await wait(for: self, timeout: timeout, reducing: initialValue, with: reducer)
    }
}

public extension Array {
    func timeout<FinalResult, PartialResult>(
        after timeout: UInt64 = .max,
        reducing initialValue: FinalResult,
        with reducer: @escaping (inout FinalResult, PartialResult) throws -> Void
    ) async throws -> FinalResult where Element == Expectation<PartialResult> {
        try await wait(for: self, timeout: timeout, reducing: initialValue, with: reducer)
    }
}

public func wait<FinalResult, PartialResult, S: Sequence>(
    for expectations: S,
    timeout: UInt64 = .max,
    reducing initialValue: FinalResult,
    with reducer: @escaping (inout FinalResult, PartialResult) throws -> Void
) async throws -> FinalResult where S.Element == Expectation<PartialResult> {
    let reducingTask = Task<FinalResult, Error>.init {
        let stateTask = await StateTask<WaitState<FinalResult, PartialResult>, WaitState<FinalResult, PartialResult>.Action>.stateTask(
            channel: .init(buffering: .bufferingOldest(expectations.underestimatedCount * 2 + 1)),
            initialState: { channel in
                .init(with: channel, for: expectations, timeout: timeout, reducer: reducer, initialValue: initialValue)
            },
            reducer: Reducer(reducer: WaitState<FinalResult, PartialResult>.reduce)
        )
        return try await stateTask.value.finalResult
    }
    return try await reducingTask.value
}
