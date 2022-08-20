//
//  TryFilter.swift
//  
//
//  Created by Van Simmons on 7/3/22.
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
    func tryFilter(
        _ isIncluded: @escaping (Output) async throws -> Bool
    ) -> Self {
        .init { continuation, downstream in
            self(onStartup: continuation) { r in switch r {
                case .value(let a):
                    do { guard try await isIncluded(a) else { return .more } }
                    catch { return try await handleCancellation(of: downstream) }
                    return try await downstream(r)
                case .completion:
                    return try await downstream(r)
            } }
        }
    }
}
