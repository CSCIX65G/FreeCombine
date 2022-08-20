//
//  Map.swift
//  
//
//  Created by Van Simmons on 3/16/22.
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
public extension Publisher {
    func map<B>(
        _ transform: @escaping (Output) async -> B
    ) -> Publisher<B> {
        .init { continuation, downstream in
            self(onStartup: continuation) { r in switch r {
                case .value(let a):
                    return try await downstream(.value(transform(a)))
                case let .completion(value):
                    return try await downstream(.completion(value))
            } }
        }
    }
}

public extension Future {
    func map<B>(
        _ transform: @escaping (Output) async -> B
    ) -> Future<B> {
        .init { continuation, downstream in
            self(onStartup: continuation) { r in switch r {
                case .success(let a):
                    return try await downstream(.success(transform(a)))
                case let .failure(error):
                    return try await downstream(.failure(error))
            } }
        }
    }
}
