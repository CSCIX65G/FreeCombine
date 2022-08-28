//
//  ReplaceError.swift
//  
//
//  Created by Van Simmons on 5/18/22.
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
    func replaceError(_ replacing: @escaping (Swift.Error) -> Output) -> Publisher<Output> {
        .init { resumption, downstream in
            self(onStartup: resumption) { r in
                switch r {
                    case .value:
                        return try await downstream(r)
                    case .completion(.failure(let e)):
                        return try await downstream(.value(replacing(e)))
                    case .completion(.finished), .completion(.cancelled):
                        return try await downstream(r)
                }
            }
        }
    }
    
    func replaceError(with value: Output) -> Publisher<Output> {
        .init { resumption, downstream in
            self(onStartup: resumption) { r in
                switch r {
                    case .value:
                        return try await downstream(r)
                    case .completion(.failure):
                        return try await downstream(.value(value))
                    case .completion(.finished), .completion(.cancelled):
                        return try await downstream(r)
                }
            }
        }
    }
}
