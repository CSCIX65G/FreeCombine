//
//  DistributorReceiveState.swift
//
//
//  Created by Van Simmons on 7/2/22.
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
public struct DistributorReceiveState<Output: Sendable> {
    var distributorChannel: Channel<DistributorState<Output>.Action>

    public enum Error: Swift.Error {
        case alreadyCompleted
    }

    public enum Action: Sendable {
        case blockingReceive(AsyncStream<Output>.Result, Resumption<Int>)
        case nonBlockingReceive(AsyncStream<Output>.Result)
    }

    public init(
        channel: Channel<DistributorState<Output>.Action>
    ) {
        self.distributorChannel = channel
    }

    static func create(
        distributorChannel: Channel<DistributorState<Output>.Action>
    ) -> (Channel<DistributorReceiveState<Output>.Action>) -> Self {
        { channel in .init(channel: distributorChannel) }
    }

    static func complete(state: inout Self, completion: Reducer<Self, Self.Action>.Completion) async -> Void { }

    static func dispose(action: Self.Action, completion: Reducer<Self, Self.Action>.Completion) async -> Void {
        switch action {
            case let .blockingReceive(_, resumption):
                switch completion {
                    case .failure(let error):
                        resumption.resume(throwing: error)
                    default:
                        resumption.resume(throwing: PublisherError.completed)
                }
            case .nonBlockingReceive(_):
                ()
        }
    }

    static func reduce(state: inout Self, action: Self.Action) async throws -> Reducer<Self, Action>.Effect {
        if Task.isCancelled {
            switch action {
                case .blockingReceive(_, let resumption):
                    resumption.resume(throwing: PublisherError.cancelled)
                case .nonBlockingReceive(_):
                    ()
            }
            return .completion(.cancel)
        }
        return try await state.reduce(action: action)
    }

    mutating func reduce(action: Action) async throws -> Reducer<Self, Action>.Effect {
        var result: AsyncStream<Output>.Result! = .none
        var resumption: Resumption<Int>! = .none
        if case let .blockingReceive(r1, r3) = action  {
            result = r1
            resumption = r3
        } else if case let .nonBlockingReceive(r2) = action {
            result = r2
        }
        do {
            let subscribers: Int = try await withResumption { innerResumption in
                switch distributorChannel.yield(.receive(result, innerResumption)) {
                    case .enqueued:
                        ()
                    case .dropped:
                        innerResumption.resume(throwing: PublisherError.enqueueError)
                    case .terminated:
                        innerResumption.resume(throwing: PublisherError.cancelled)
                    @unknown default:
                        fatalError("Unhandled resumption value")
                }
            }
            resumption?.resume(returning: subscribers)
            return .none
        } catch {
            resumption?.resume(throwing: error)
            return .completion(.failure(error))
        }
    }
}
