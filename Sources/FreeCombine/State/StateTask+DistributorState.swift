//
//  StateTask+DistributorState.swift
//  
//
//  Created by Van Simmons on 5/13/22.
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
    @inlinable
    func send<Output: Sendable>(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line,
        _ value: Output
    ) async throws -> Void where State == DistributorState<Output>, Action == DistributorState<Output>.Action {
        try await send(
            function: function,
            file: file,
            line: line,
            .value(value)
        )
    }

    @discardableResult
    func send<Output: Sendable>(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line,
        _ result: AsyncStream<Output>.Result
    ) async throws -> Int where State == DistributorState<Output>, Action == DistributorState<Output>.Action {
        var enqueueResult: AsyncStream<DistributorState<Output>.Action>.Continuation.YieldResult!
        let subscribers: Int = try await withResumption(function: function, file: file, line: line) { resumption in
            enqueueResult = send(.receive(result, resumption))
            guard case .enqueued = enqueueResult else {
                resumption.resume(throwing: PublisherError.enqueueError)
                return
            }
        }
        guard case .enqueued = enqueueResult else {
            throw PublisherError.enqueueError
        }
        return subscribers
    }

    @inlinable
    func fail<Output: Sendable>(
        _ error: Error
    ) async throws -> Void where State == DistributorState<Output>, Action == DistributorState<Output>.Action {
        try await send(.completion(.failure(error)))
    }
}
