//
//  StateTask+PromiseState.swift
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
        deinitBehavior: DeinitBehavior = .assert,
        _ value: Output
    ) async throws -> Void where State == PromiseState<Output>, Action == PromiseState<Output>.Action {
        try await send(
            file: file,
            line: line,
            deinitBehavior: deinitBehavior,
            .success(value)
        )
    }

    @discardableResult
    func send<Output: Sendable>(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line,
        deinitBehavior: DeinitBehavior = .assert,
        _ result: Result<Output, Swift.Error>
    ) async throws -> Int where State == PromiseState<Output>, Action == PromiseState<Output>.Action {
        var enqueueResult: AsyncStream<PromiseState<Output>.Action>.Continuation.YieldResult!
        let subscribers: Int = try await withResumption(file: file, line: line, deinitBehavior: deinitBehavior) { resumption in
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

    func succeed<Output: Sendable>(
        _ value: Output
    ) async throws -> Void where State == PromiseState<Output>, Action == PromiseState<Output>.Action {
        try await send(.success(value))
    }

    func cancel<Output: Sendable>(
    ) async throws -> Void where State == PromiseState<Output>, Action == PromiseState<Output>.Action {
        try await send(.failure(PublisherError.cancelled))
        cancellable.cancel()
    }

    @inlinable
    func fail<Output: Sendable>(
        _ error: Error
    ) async throws -> Void where State == PromiseState<Output>, Action == PromiseState<Output>.Action {
        try await send(.failure(error))
    }
}
