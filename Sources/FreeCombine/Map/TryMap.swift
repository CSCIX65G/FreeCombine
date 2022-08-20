//
//  TryMap.swift
//  
//
//  Created by Van Simmons on 5/15/22.
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
    func tryMap<B>(_ transform: @escaping (Output) async throws -> B) -> Publisher<B> {
        .init { continuation, downstream in
            self(onStartup: continuation) { r in
                guard !Task.isCancelled else {
                    return try await handleCancellation(of: downstream)
                }
                switch r {
                    case .value(let a):
                        var b: B!
                        do { b = try await transform(a) }
                        catch { return try await downstream(.completion(.failure(error))) }
                        return try await downstream(.value(b))
                    case let .completion(value):
                        return try await downstream(.completion(value))
                }
            }
        }
    }
}
