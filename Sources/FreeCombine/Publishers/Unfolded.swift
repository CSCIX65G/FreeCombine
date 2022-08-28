//
//  Unfolded.swift
//  
//
//  Created by Van Simmons on 5/18/22.
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
public extension Sequence {
    var asyncPublisher: Publisher<Element> {
        Unfolded(self)
    }
}

public func Unfolded<S: Sequence>(_ sequence: S) -> Publisher<S.Element> {
    .init(sequence)
}

public extension Publisher {
    init<S: Sequence>(_ sequence: S) where S.Element == Output {
        self = .init { resumption, downstream in
            Cancellable<Demand> {
                resumption.resume()
                for a in sequence {
                    guard !Task.isCancelled else {
                        return try await handleCancellation(of: downstream)
                    }
                    guard try await downstream(.value(a)) == .more else {
                        return .done
                    }
                }
                return Task.isCancelled
                    ? try await downstream(.completion(.cancelled))
                    : try await downstream(.completion(.finished))
            }
        }
    }
}

public func Unfolded<Element>(
    _ generator: @escaping () async throws -> Element?
) -> Publisher<Element> {
    .init(generator)
}

public extension Publisher {
    init(_ generator: @escaping () async throws -> Output?) {
        self = .init { resumption, downstream in
                .init {
                    resumption.resume()
                    while let a = try await generator() {
                        guard !Task.isCancelled else {
                            return try await handleCancellation(of: downstream)
                        }
                        guard try await downstream(.value(a)) == .more else { return .done }
                    }
                    return try await downstream(.completion(.finished))
                }
        }
    }
}
