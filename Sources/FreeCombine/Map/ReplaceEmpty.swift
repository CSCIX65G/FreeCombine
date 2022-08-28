//
//  ReplaceEmpty.swift
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
    func replaceEmpty(
        with value: Output
    ) -> Self {
        .init { resumption, downstream in
            let isEmpty = ValueRef<Bool>(value: true)
            return self(onStartup: resumption) { r in switch r {
                case .value(let a):
                    isEmpty.set(value: false)
                    return try await downstream(.value(a))
                case let .completion(completion):
                    if isEmpty.value {
                        // Send the value to replace an emptyStream
                        _ = try await downstream(.value(value))
                    }
                    return try await downstream(.completion(completion))
            } }
        }
    }
}
