//
//  DropFirst.swift
//  
//
//  Created by Van Simmons on 6/4/22.
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
    func dropFirst(
        _ count: Int = 1
    ) -> Self {
        .init { continuation, downstream in
            let currentValue: ValueRef<Int> = ValueRef(value: count + 1)
            return self(onStartup: continuation) { r in
                let current = currentValue.value - 1
                try currentValue.set(value: max(0, current))
                switch r {
                case .value:
                    guard current <= 0 else { return .more }
                    return try await downstream(r)
                case let .completion(value):
                    return try await downstream(.completion(value))
            } }
        }
    }
}
