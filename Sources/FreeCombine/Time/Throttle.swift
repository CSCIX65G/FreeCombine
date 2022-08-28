//
//  Throttle.swift
//  
//
//  Created by Van Simmons on 7/4/22.
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
extension Publisher {
    enum ThrottlerError: Error {
        case alreadyActivated
    }
    class Throttler {
        private(set) var subject: Subject<Output>!
        private(set) var cancellable: Cancellable<Demand>!
        private(set) var timerCancellable: Cancellable<Demand>!

        var value: AsyncStream<Output>.Result? = .none
        func set(value: AsyncStream<Output>.Result?) { self.value = value }
        var completion: AsyncStream<Output>.Result? = .none
        func set(completion: AsyncStream<Output>.Result?) { self.completion = completion }

        func activate (
            interval: Duration,
            latest: Bool = false,
            downstream: @escaping @Sendable (AsyncStream<Output>.Result) async throws -> Demand
        ) async throws -> Void {
            guard subject == nil else { return }
            subject = try await PassthroughSubject(buffering: .bufferingNewest(1))
            cancellable = await subject.asyncPublisher.sink(downstream)
            timerCancellable = await Heartbeat(interval: interval).sink { _ in
                if let value = self.value {
                    try await self.subject.blockingSend(value)
                    self.set(value: .none)
                }
                if let completion = self.completion {
                    try await self.subject.blockingSend(completion)
                    try await self.cleanup()
                }
            }
        }

        fileprivate func cleanup() async throws  -> Void {
            _ = await timerCancellable.cancelAndAwaitResult()
            try await subject.finish()
            _ = await cancellable.result
            _ = await subject.result
        }
    }

    func throttle(
        interval: Duration,
        latest: Bool = false,
        bufferSize: Int = 1
    ) -> Self {
        .init { resumption, downstream in
            let throttler: Throttler = .init()
            return self(onStartup: resumption) { r in
                try await throttler.activate(interval: interval, latest: latest, downstream: downstream)

                // Check for cancellation
                let isCancelled = throttler.cancellable.isCancelled
                guard !Task.isCancelled && !isCancelled else {
                    try await throttler.cleanup()
                    return try await handleCancellation(of: downstream)
                }

                switch r {
                    case .value:
                        let value = throttler.value
                        if value == nil || latest { throttler.set(value: r); return .more }
                        return .more
                    case .completion(.finished), .completion(.cancelled):
                        throttler.set(completion: r)
                        return try await throttler.cancellable.value
                    case .completion(.failure(let error)):
                        throttler.set(completion: r)
                        _ = try await throttler.cancellable.value
                        throw error
                }
            }
        }
    }
}
