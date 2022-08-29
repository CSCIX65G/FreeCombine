//
//  Future.swift
//  
//
//  Created by Van Simmons on 7/10/22.
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
public enum FutureError: Swift.Error, Sendable, CaseIterable {
    case cancelled
    case internalError
}

public struct Future<Output: Sendable>: Sendable {
    private let call: @Sendable (
        Resumption<Void>,
        @escaping @Sendable (Result<Output, Swift.Error>) async -> Void
    ) -> Cancellable<Void>

    internal init(
        _ call: @escaping @Sendable (
            Resumption<Void>,
            @escaping @Sendable (Result<Output, Swift.Error>) async -> Void
        ) -> Cancellable<Void>
    ) {
        self.call = call
    }
}

public extension Future {
    var publisher: Publisher<Output> {
        .init { resumption, downstream in
                .init {
                    let demandRef: ValueRef<Result<Demand, Swift.Error>> = .init(value: .failure(PublisherError.internalError))
                    let innerCancellable = await self.sink { result in
                        do {
                            switch result {
                                case let .success(value):
                                    guard try await downstream(.value(value)) == .more else {
                                        demandRef.set(value: .success(.done))
                                        return
                                    }
                                    let demand = try await downstream(.completion(.finished))
                                    demandRef.set(value: .success(demand))
                                case let .failure(error):
                                    switch error {
                                        case FutureError.cancelled:
                                            _ = try await downstream(.completion(.cancelled))
                                            demandRef.set(value: .failure(PublisherError.cancelled))
                                        default:
                                            _ = try await downstream(.completion(.failure(error)))
                                            demandRef.set(value: .failure(error))
                                    }
                            }
                        } catch {
                            demandRef.set(value: .failure(error))
                        }
                    }
                    resumption.resume()
                    _ = await innerCancellable.result
                    return try demandRef.value.get()
                }
        }
    }
}

public extension Future {
    @discardableResult
    func sink(
        onStartup: Resumption<Void>,
        _ downstream: @escaping @Sendable (Result<Output, Swift.Error>) async -> Void
    ) -> Cancellable<Void> {
        self(onStartup: onStartup, downstream)
    }

    @discardableResult
    func callAsFunction(
        onStartup: Resumption<Void>,
        _ downstream: @escaping @Sendable (Result<Output, Swift.Error>) async -> Void
    ) -> Cancellable<Void> {
        call(onStartup, { result in
            guard !Task.isCancelled else {
                return await handleFutureCancellation(of: downstream)
            }
            return await downstream(result)
        } )
    }

    @discardableResult
    func sink(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line,
        _ downstream: @escaping @Sendable (Result<Output, Swift.Error>) async -> Void
    ) async -> Cancellable<Void> {
        await self(function: function, file: file, line: line, downstream)
    }

    @discardableResult
    func callAsFunction(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line,
        _ downstream: @escaping @Sendable (Result<Output, Swift.Error>) async -> Void
    ) async -> Cancellable<Void> {
        var cancellable: Cancellable<Void>!
        let _: Void = try! await withResumption(function: function, file: file, line: line) { resumption in
            cancellable = self(onStartup: resumption, downstream)
        }
        return cancellable
    }
}

func handleFutureCancellation<Output>(
    of downstream: @escaping @Sendable (Result<Output, Swift.Error>) async -> Void
) async -> Void {
    _ = await downstream(.failure(FutureError.cancelled))
}
