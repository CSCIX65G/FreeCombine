//
//  Encode.swift
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
    struct TopLevelEncoder<T> {
        var encoder: (Output) throws -> T
        init(encoder: @escaping (Output) throws -> T) {
            self.encoder = encoder
        }
        func encode(_ data: Output) throws -> T {
            try encoder(data)
        }
    }

    func encode<Item: Decodable>(
        encoder: TopLevelEncoder<Item>
    ) -> Publisher<Item> {
        .init { resumption, downstream in
            self(onStartup: resumption) { r in
                switch r {
                    case .value(let data):
                        do { return try await downstream(.value(encoder.encode(data))) }
                        catch { return try await downstream(.completion(.failure(error))) }
                    case let .completion(value):
                        return try await downstream(.completion(value))
                }
            }
        }
    }
}
