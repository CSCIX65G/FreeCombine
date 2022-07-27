//
//  PromiseReceiveState.swift
//  
//
//  Created by Van Simmons on 7/27/22.
//
public struct PromiseReceiveState<Output: Sendable> {
    var promiseChannel: Channel<PromiseState<Output>.Action>

    public enum Error: Swift.Error {
        case alreadyCompleted
    }

    public enum Action: Sendable {
        case receive(Result<Output, Swift.Error>, Resumption<Int>)
        case nonBlockingReceive(Result<Output, Swift.Error>)
    }

    public init(
        channel: Channel<PromiseState<Output>.Action>
    ) {
        self.promiseChannel = channel
    }

    static func create(
        promiseChannel: Channel<PromiseState<Output>.Action>
    ) -> (Channel<PromiseReceiveState<Output>.Action>) -> Self {
        { channel in .init(channel: promiseChannel) }
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
        var result: Result<Output, Swift.Error>! = .none
        var resumption: Resumption<Int>! = .none
        if case let .receive(r1, r3) = action  {
            result = r1
            resumption = r3
        } else if case let .nonBlockingReceive(r2) = action {
            result = r2
        }
        do {
            let subscribers: Int = try await withResumption { innerResumption in
                switch promiseChannel.yield(.receive(result, innerResumption)) {
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
