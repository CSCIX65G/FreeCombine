//
//  FireAndForget.swift
//  
//
//  Created by Van Simmons on 5/26/22.
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
public func SideEffect<Element>(
    _ elementType: Element.Type = Element.self,
    operation: @escaping () async throws -> Void
) -> Publisher<Element> {
    .init(elementType)
}

public extension Publisher {
    static func fireAndForget(_ operation: @escaping () async throws -> Void) -> Self {
        SideEffect(Output.self, operation: operation)
    }

    init(
        _: Output.Type = Output.self,
        operation: @escaping () async throws -> Void
    ) {
        self = .init { resumption, downstream in
            .init {
                resumption.resume()
                do {
                    try await operation()
                    guard !Task.isCancelled else {
                        return try await handleCancellation(of: downstream)
                    }
                    return try await downstream(.completion(.finished))
                } catch {
                    return try await downstream(.completion(.failure(error)))
                }
            }
        }
    }
}
