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
        case receive(AsyncStream<Output>.Result, Resumption<Int>)
        case nonBlockingReceive(AsyncStream<Output>.Result)
    }

    public init(
        channel: Channel<DistributorState<Output>.Action>
    ) {
        self.distributorChannel = channel
    }

    static func create(
        distributorChannel: Channel<DistributorState<Output>.Action>
    ) -> (Channel<RepeatReceiveState<Output>.Action>) -> Self {
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
            case .nonBlockingReceive(_):
                ()
        }
    }

    static func reduce(state: inout Self, action: Self.Action) async throws -> Reducer<Self, Action>.Effect {
        if Task.isCancelled {
            switch action {
                case .receive(_, let resumption):
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
        if case let .receive(r1, r3) = action  {
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
                        fatalError("Unhandled continuation value")
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
