//
//  HandleEvents.swift
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
    func handleEvents(
        receiveDownstream: @escaping (@escaping (AsyncStream<Output>.Result) async throws -> Demand) -> Void = {_ in },
        receiveResult: @escaping (AsyncStream<Output>.Result) async -> Void = { _ in },
        receiveDemand: @escaping (Demand) async -> Void = { _ in }
    ) -> Self {
        .init { resumption, downstream in
            receiveDownstream(downstream)
            return self(onStartup: resumption) { r in
                await receiveResult(r)
                let demand = try await downstream(r)
                await receiveDemand(demand)
                return demand
            }
        }
    }

    func handleEvents(
        receiveDownstream: @escaping (@escaping (AsyncStream<Output>.Result) async throws -> Demand) -> Void = {_ in },
        receiveOutput: @escaping (Output) async -> Void = { _ in },
        receiveFinished: @escaping () async -> Void = { },
        receiveFailure: @escaping (Swift.Error) async -> Void = {_ in },
        receiveCancel: @escaping () async -> Void = { },
        receiveDemand: @escaping (Demand) async -> Void = { _ in }
    ) -> Self {
        .init { resumption, downstream in
            receiveDownstream(downstream)
            return self(onStartup: resumption) { r in
                switch r {
                    case .value(let a):
                        await receiveOutput(a)
                    case .completion(.finished):
                        await receiveFinished()
                    case .completion(.cancelled):
                        await receiveCancel()
                    case let .completion(.failure(error)):
                        await receiveFailure(error)
                }
                let demand = try await downstream(r)
                await receiveDemand(demand)
                return demand
            }
        }
    }
}
