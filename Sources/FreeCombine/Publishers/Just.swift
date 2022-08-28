//
//  Just.swift
//  
//
//  Created by Van Simmons on 3/15/22.
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
public func Just<Element>(_ a: Element) -> Publisher<Element> {
    .init(a)
}

public extension Publisher {
    init(_ a: Output) {
        self = .init { resumption, downstream in
            .init {
                resumption.resume()
                return try await downstream(.value(a)) == .more ? try await downstream(.completion(.finished)) : .done
            }
        }
    }
}

public func Just<Element>(_ generator: @escaping () async -> Element) -> Publisher<Element> {
    .init(generator)
}

public extension Publisher {
    init(_ generator: @escaping () async -> Output) {
        self = .init { resumption, downstream in
            .init {
                resumption.resume()
                return try await downstream(.value(generator())) == .more ? try await downstream(.completion(.finished)) : .done
            }
        }
    }
}

public func Just<Element>(_ a: AsyncStream<Element>.Result) -> Publisher<Element> {
    .init(a)
}

public extension Publisher {
    init(_ result: AsyncStream<Output>.Result) {
        self = .init { resumption, downstream in
            .init {
                resumption.resume()
                return try await downstream(result) == .more ? try await downstream(.completion(.finished)) : .done
            }
        }
    }
}

public func Just<Element>(_ generator: @escaping () async -> AsyncStream<Element>.Result) -> Publisher<Element> {
    .init(generator)
}

public extension Publisher {
    init(_ generator: @escaping () async -> AsyncStream<Output>.Result) {
        self = .init { resumption, downstream in
            .init {
                resumption.resume()
                return try await downstream(generator()) == .more ? try await downstream(.completion(.finished)) : .done
            }
        }
    }
}
