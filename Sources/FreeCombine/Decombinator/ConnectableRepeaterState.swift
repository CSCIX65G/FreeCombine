//
//  RepeatDistributeState.swift
//  
//
//  Created by Van Simmons on 7/3/22.
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
public struct ConnectableRepeaterState<Output: Sendable> {
    var distributorChannel: Channel<ConnectableState<Output>.Action>

    public enum Error: Swift.Error {
        case alreadyCompleted
    }

    public enum Action: Sendable {
        case receive(AsyncStream<Output>.Result, Resumption<Int>)
    }

    public init(
        channel: Channel<ConnectableState<Output>.Action>
    ) {
        self.distributorChannel = channel
    }

    static func create(
        distributorChannel: Channel<ConnectableState<Output>.Action>
    ) -> (Channel<ConnectableRepeaterState<Output>.Action>) -> Self {
        { channel in .init(channel: distributorChannel) }
    }

    static func complete(state: inout Self, completion: Reducer<Self, Self.Action>.Completion) async -> Void { }

    static func dispose(action: Self.Action, completion: Reducer<Self, Self.Action>.Completion) async -> Void {
        switch action {
            case let .receive(_, resumption):
                switch completion {
                    case .failure(let error):
                        resumption.resume(throwing: error)
                    default:
                        resumption.resume(throwing: PublisherError.completed)
                }
        }
    }

    static func reduce(`self`: inout Self, action: Self.Action) async throws -> Reducer<Self, Action>.Effect {
        if Task.isCancelled {
            switch action {
                case .receive(_, let resumption):
                    resumption.resume(throwing: PublisherError.cancelled)
            }
            return .completion(.cancel)
        }
        return try await `self`.reduce(action: action)
    }

    mutating func reduce(action: Action) async throws -> Reducer<Self, Action>.Effect {
        guard case let .receive(result, resumption) = action else {
            fatalError("Unknown action")
        }
        do {
            let subscribers: Int = try await withResumption { innerResumption in
                switch distributorChannel.yield(.distribute(.receive(result, innerResumption))) {
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
            resumption.resume(returning: subscribers)
            return .none
        } catch {
            resumption.resume(throwing: error)
            return .completion(.failure(error))
        }
    }
}
