//
//  Collect.swift
//  
//
//  Created by Van Simmons on 5/19/22.
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
    func collect() -> Publisher<[Output]> {
        return .init { continuation, downstream in
            let currentValue: ValueRef<[Output]> = ValueRef(value: [])
            return self(onStartup: continuation) { r in
                guard !Task.isCancelled else {
                    return try await handleCancellation(of: downstream)
                }
                switch r {
                    case .value(let a):
                        try currentValue.append(a)
                        return .more
                    case let .completion(value):
                        _ = try await downstream(.value(currentValue.value))
                        return try await downstream(.completion(value))
                }
            }
        }
    }
}
