//
//  Print.swift
//  
//
//  Created by Van Simmons on 6/6/22.
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
    func print(prefix: String = "") -> Self {
        return .init { resumption, downstream in
            _ = Swift.print("\(prefix) received subscriber: \(type(of: downstream))")
            return self(onStartup: resumption) { r in
                switch r {
                    case .value(let a):
                        _ = Swift.print("\(prefix) received value: \(a))")
                    case .completion(.finished):
                        _ = Swift.print("\(prefix) received .completion(.finished))")
                    case .completion(.cancelled):
                        _ = Swift.print("\(prefix) received .completion(.cancelled))")
                    case let .completion(.failure(error)):
                        _ = Swift.print("\(prefix) received .completion(.failure(\(error)))")
                }
                let demand = try await downstream(r)
                _ = Swift.print("\(prefix) received Demand(\(demand)))")
                return demand
            }
        }
    }
}
