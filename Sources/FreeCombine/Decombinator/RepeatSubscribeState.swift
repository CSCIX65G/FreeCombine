//
//  SubscriberState.swift
//
//
//  Created by Van Simmons on 5/10/22.
//
public struct RepeatSubscribeState<Output: Sendable> {
    var distributorChannel: Channel<DistributorState<Output>.Action>

    public enum Error: Swift.Error {
        case alreadyCompleted
    }

    public enum Action: Sendable {
        case subscribe(
            @Sendable (AsyncStream<Output>.Result) async throws -> Demand,
            Resumption<Cancellable<Demand>>
        )
    }

    public init(
        distributorChannel: Channel<DistributorState<Output>.Action>
    ) {
        self.distributorChannel = distributorChannel
    }

    static func create(
        distributorChannel: Channel<DistributorState<Output>.Action>
    ) -> (Channel<RepeatSubscribeState<Output>.Action>) -> Self {
        { channel in .init(distributorChannel: distributorChannel) }
    }

    static func complete(state: inout Self, completion: Reducer<Self, Self.Action>.Completion) async -> Void { }

    static func dispose(action: Self.Action, completion: Reducer<Self, Self.Action>.Completion) async -> Void {
        switch action {
            case let .subscribe(_, continuation):
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
                case let .subscribe(_, resumption):
                    resumption.resume(throwing: PublisherError.cancelled)
            }
            return .completion(.cancel)
        }
        return try await `self`.reduce(action: action)
    }

    mutating func reduce(action: Action) async throws -> Reducer<Self, Action>.Effect {
        switch action {
            case let .subscribe(downstream, resumption):
                switch distributorChannel.yield(.subscribe(downstream, resumption)) {
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
