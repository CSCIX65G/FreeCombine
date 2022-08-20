//
//  Concat.swift
//  
//
//  Created by Van Simmons on 5/17/22.
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
public extension Publisher  {
    func concat(_ other: Publisher<Output>) -> Publisher<Output> {
        .init(concatenating: [self, other])
    }
}

public func Concat<Output, S: Sequence>(
    _ publishers: S
) -> Publisher<Output> where S.Element == Publisher<Output>{
    .init(concatenating: publishers)
}

public extension Publisher {
    init<S: Sequence>(
        concatenating publishers: S
    ) where S.Element == Publisher<Output> {
        self = .init { continuation, downstream  in
            let flattenedDownstream = flattener(downstream)
            return .init {
                continuation.resume()
                for p in publishers {
                    let t = await p(flattenedDownstream)
                    guard try await t.value == .more else { return .done }
                }
                return try await downstream(.completion(.finished))
            }
        }
    }
}

public func Concat<Element>(
    _ publishers: Publisher<Element>...
) -> Publisher<Element> {
    .init(concatenating: publishers)
}

public extension Publisher {
    init(
        concatenating publishers: Publisher<Output>...
    ) {
        self = .init(concatenating: publishers)
    }
}

public func Concat<Element>(
    _ publishers: @escaping () async -> Publisher<Element>?
) -> Publisher<Element> {
    .init(flattening: publishers)
}

public extension Publisher {
    init(
        flattening: @escaping () async -> Publisher<Output>?
    ) {
        self = .init { continuation, downstream  in
            let flattenedDownstream = flattener(downstream)
            return .init {
                continuation.resume()
                while let p = await flattening() {
                    let t = await p(flattenedDownstream)
                    guard try await t.value == .more else { return .done }
                }
                return try await downstream(.completion(.finished))
            }
        }
    }
}
