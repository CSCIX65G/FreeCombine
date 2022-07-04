//
//  RepeatDistributeState.swift
//  
//
//  Created by Van Simmons on 7/3/22.
//
public struct RepeatDistributeState<Output: Sendable> {
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
    ) -> (Channel<RepeatDistributeState<Output>.Action>) -> Self {
        { channel in .init(channel: distributorChannel) }
    }

    static func complete(state: inout Self, completion: Reducer<Self, Self.Action>.Completion) async -> Void { }

    static func dispose(action: Self.Action, completion: Reducer<Self, Self.Action>.Completion) async -> Void {
        switch action {
            case let .receive(_, continuation):
                switch completion {
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    default:
                        continuation.resume(throwing: PublisherError.completed)
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
                        fatalError("Unhandled continuation value")
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
