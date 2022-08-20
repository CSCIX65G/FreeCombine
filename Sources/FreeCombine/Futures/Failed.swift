//
//  Failed.swift
//  
//
//  Created by Van Simmons on 8/11/22.
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
public func Failed<Output>(_ e: Swift.Error) -> Future<Output> {
    .init(e)
}

public extension Future {
    init(_ e: Swift.Error) {
        self = .init { continuation, downstream in .init {
            continuation.resume()
            return try await downstream(.failure(e))
        } }
    }
}

public func Fail<Output>(_ generator: @escaping () async -> Swift.Error) -> Future<Output> {
    .init(generator)
}

public extension Future {
    init(_ generator: @escaping () async -> Swift.Error) {
        self = .init { continuation, downstream in  .init {
            continuation.resume()
            return try await downstream(.failure(generator()))
        } }
    }
}
