//
//  Multicast.swift
//  
//
//  Created by Van Simmons on 6/26/22.
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
    func multicast(_ subject: Subject<Output>) -> Self {
        .init { resumption, downstream in
            self.sink(onStartup: resumption, { result in
                switch result {
                    case .completion(.failure(let error)):
                        try await subject.fail(error)
                    case .completion(.cancelled):
                        try await subject.cancel()
                    case .completion(.finished):
                        try await subject.finish()
                    case .value(let value):
                        try await subject.blockingSend(value)
                }
                return try await downstream(result)
            })
        }
    }

    func multicast(
        _ generator: @escaping () -> StateTask<DistributorState<Output>, DistributorState<Output>.Action>
    ) async -> Self {
        let subject = generator()
        return .init { resumption, downstream in
            self.sink(onStartup: resumption, { result in
                switch result {
                    case .completion(.failure(let error)):
                        try await subject.fail(error)
                    case .completion(.cancelled):
                        subject.cancel()
                    case .completion(.finished):
                        subject.finish()
                    case .value(let value):
                        try await subject.send(value)
                }
                return try await downstream(result)
            })
        }
    }
}
