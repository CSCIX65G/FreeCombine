//
//  RepeatReceiveState.swift
//
//
//  Created by Van Simmons on 7/2/22.
//
public struct RepeatReceiveState<Output: Sendable> {
    var distributorChannel: Channel<DistributorState<Output>.Action>

    public enum Error: Swift.Error {
        case alreadyCompleted
    }

    public enum Action: Sendable {
        case receive(AsyncStream<Output>.Result, Resumption<Void>)
    }

    public init(
        distributorChannel: Channel<DistributorState<Output>.Action>
    ) {
        self.distributorChannel = distributorChannel
    }

    static func create(
        distributorChannel: Channel<DistributorState<Output>.Action>
    ) -> (Channel<RepeatReceiveState<Output>.Action>) -> Self {
        { channel in .init(distributorChannel: distributorChannel) }
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
        switch action {
            case let .receive(result, resumption):
                switch distributorChannel.yield(.receive(result, resumption)) {
                    case .enqueued:
                        return .none
                    case .dropped:
                        resumption.resume(throwing: PublisherError.enqueueError)
                        return .completion(.failure(PublisherError.enqueueError))
                    case .terminated:
                        resumption.resume(throwing: PublisherError.cancelled)
                        return .completion(.failure(PublisherError.cancelled))
                    @unknown default:
                        fatalError("Unhandled continuation value")
                }
        }
    }
}
