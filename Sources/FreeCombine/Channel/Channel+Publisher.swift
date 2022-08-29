//
//  Channel+Publisher.swift
//  
//
//  Created by Van Simmons on 7/1/22.
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
public extension Channel {
    func consume<Upstream>(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line,
        publisher: Publisher<Upstream>
    ) async -> Cancellable<Demand> where Element == (AsyncStream<Upstream>.Result, Resumption<Demand>) {
        await consume(file: file, line: line, publisher: publisher, using: { ($0, $1) })
    }

    func consume<Upstream>(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line,
        publisher: Publisher<Upstream>,
        using action: @escaping (AsyncStream<Upstream>.Result, Resumption<Demand>) -> Element
    ) async -> Cancellable<Demand>  {
        await publisher { upstreamValue in
            try await withResumption(file: file, line: line) { resumption in
                if Task.isCancelled {
                    resumption.resume(throwing: PublisherError.cancelled)
                    return
                }
                switch self.yield(action(upstreamValue, resumption)) {
                    case .enqueued:
                        ()
                    case .dropped:
                        resumption.resume(throwing: PublisherError.enqueueError)
                    case .terminated:
                        resumption.resume(throwing: PublisherError.cancelled)
                    @unknown default:
                        fatalError("Unhandled resumption value")
                }
            }
        }
    }

    func consume<Upstream>(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line,
        future: Future<Upstream>,
        using action: @escaping (Result<Upstream, Swift.Error>, Resumption<Void>) -> Element
    ) async -> Cancellable<Void>  {
        await future { upstreamValue in
//            do {
//                try await withResumption(function: function, file: file, line: line) { resumption in
//                    guard !Task.isCancelled else {
//                        resumption.resume(throwing: PublisherError.cancelled)
//                        return
//                    }
//                    switch self.yield(action(upstreamValue, resumption)) {
//                        case .enqueued:
//                            ()
//                        case .dropped:
//                            resumption.resume(throwing: PublisherError.enqueueError)
//                        case .terminated:
//                            resumption.resume(throwing: PublisherError.cancelled)
//                        @unknown default:
//                            fatalError("Unhandled resumption value")
//                    }
//                }
//            } catch { }
            return
        }
    }
}
