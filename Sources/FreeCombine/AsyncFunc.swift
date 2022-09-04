//
//  AsyncFunc.swift
//  
//
//  Created by Van Simmons on 9/3/22.
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
public struct AsyncFunc<A, B> {
    private let call: (A) async throws -> B
    public init(_ call: @escaping (A) async throws -> B) {
        self.call = call
    }
    public func callAsFunction(_ a: A) async throws -> B {
        try await call(a)
    }
}

extension AsyncFunc {
    public func map<C>(
        _ transform: @escaping (B) async throws -> C
    ) -> AsyncFunc<A, C> {
        .init { a in try await transform(call(a)) }
    }
    public func flatMap<C>(
        _ transform: @escaping (B) async throws -> AsyncFunc<A, C>
    ) -> AsyncFunc<A, C> {
        .init { a in try await transform(call(a))(a) }
    }
}
