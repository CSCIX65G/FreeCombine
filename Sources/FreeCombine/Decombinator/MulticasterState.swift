//
//  MulticasterState.swift
//  
//
//  Created by Van Simmons on 6/5/22.
//

public struct MulticasterState<Output: Sendable> {
    public enum Action: Sendable, CustomStringConvertible {
        case connect(UnsafeContinuation<Void, Swift.Error>)
        case pause(UnsafeContinuation<Void, Swift.Error>)
        case resume(UnsafeContinuation<Void, Swift.Error>)
        case disconnect(UnsafeContinuation<Void, Swift.Error>)
        case distribute(DistributorState<Output>.Action)

        public var description: String {
            switch self {
                case .connect: return "connect"
                case .pause: return "pause"
                case .resume: return "resume"
                case .disconnect: return "disconnect"
                case let .distribute(subaction): return "distribute(\(subaction))"
            }
        }
    }

    public enum Error: Swift.Error {
        case alreadyConnected
        case alreadyDisconnected
        case disconnected
        case alreadyPaused
        case alreadyResumed
        case alreadyCompleted
        case internalError
    }

    let upstream: Publisher<Output>
    let downstream: @Sendable (AsyncStream<Output>.Result) async throws -> Demand

    var cancellable: Cancellable<Demand>?
    var upstreamContinuation: UnsafeContinuation<Demand, Swift.Error>?
    var isRunning: Bool = false
    var distributor: DistributorState<Output>

    public init(
        upstream: Publisher<Output>,
        channel: Channel<MulticasterState<Output>.Action>
    ) {
        self.upstream = upstream

        self.distributor = .init(currentValue: .none, nextKey: 0, downstreams: [:])
        self.downstream = { r in
            var queueStatus: AsyncStream<MulticasterState<Output>.Action>.Continuation.YieldResult!
            let _: Void = await withUnsafeContinuation { continuation in
                queueStatus = channel.yield(.distribute(.receive(r, continuation)))
                switch queueStatus {
                    case .enqueued, .terminated:
                        ()
                    case .dropped:
                        fatalError("Should never drop")
                    case .none:
                        fatalError("must have a queue status")
                    @unknown default:
                        fatalError("Handle new case")
                }
            }
            if case .enqueued = queueStatus { return .more }
            return .done
        }
    }

    static func create(
        upstream: Publisher<Output>
    ) -> (Channel<MulticasterState<Output>.Action>) -> Self {
        { channel in return .init(upstream: upstream, channel: channel) }
    }

    static func complete(state: inout Self, completion: Reducer<Self, Self.Action>.Completion) async -> Void {
        switch completion {
            case .finished, .exit:
                await state.distributor.process(currentRepeaters: state.distributor.repeaters, with: .completion(.finished))
            case let .failure(error):
                await state.distributor.process(currentRepeaters: state.distributor.repeaters, with: .completion(.failure(error)))
            case .cancel:
                await state.distributor.process(currentRepeaters: state.distributor.repeaters, with: .completion(.cancelled))
        }
        for (_, repeater) in state.distributor.repeaters {
            repeater.finish()
        }
        state.distributor.repeaters.removeAll()
        state.cancellable?.cancel()
    }

    static func distributorCompletion(
        _ completion: Reducer<Self, Self.Action>.Completion
    ) -> Reducer<DistributorState<Output>, DistributorState<Output>.Action>.Completion {
        switch completion {
            case .finished: return .finished
            case .exit: return .exit
            case let .failure(error): return .failure(error)
            case .cancel: return .cancel
        }
    }

    static func dispose(action: Self.Action, completion: Reducer<Self, Self.Action>.Completion) async -> Void {
        switch action {
            case let .connect(continuation):
                continuation.resume(throwing: Error.alreadyCompleted)
            case let .pause(continuation):
                continuation.resume(throwing: Error.alreadyCompleted)
            case let .resume(continuation):
                continuation.resume(throwing: Error.alreadyCompleted)
            case let .disconnect(continuation):
                continuation.resume(throwing: Error.alreadyCompleted)
            case let .distribute(distributorAction):
                await DistributorState<Output>.dispose(action: distributorAction, completion: distributorCompletion(completion))
        }
    }

    static func reduce(`self`: inout Self, action: Self.Action) async throws -> Reducer<Self, Action>.Effect {
        return try await `self`.reduce(action: action)
    }

    mutating func reduce(action: Action) async throws -> Reducer<Self, Action>.Effect {
        switch action {
            case let .connect(continuation):
                return try await connect(continuation)
            case let .pause(continuation):
                return try await pause(continuation)
            case let .resume(continuation):
                return try await resume(continuation)
            case let .disconnect(continuation):
                return try await disconnect(continuation)
            case let .distribute(action):
                return try await distribute(action)
        }
    }

    mutating func connect(
        _ continuation: UnsafeContinuation<Void, Swift.Error>
    ) async throws -> Reducer<Self, Action>.Effect {
        guard case .none = cancellable else {
            continuation.resume()
            return .none
        }
        let localUpstream = upstream
        let localDownstream = downstream
        cancellable = Cancellable<Demand>.join {
            await localUpstream.sink(localDownstream)
        }
        isRunning = true
        continuation.resume()
        return .none
    }

    mutating func pause(
        _ continuation: UnsafeContinuation<Void, Swift.Error>
    ) async throws -> Reducer<Self, Action>.Effect {
        guard let _ = cancellable else {
            continuation.resume(throwing: Error.disconnected)
            return .completion(.failure(Error.disconnected))
        }
        guard isRunning else {
            continuation.resume(throwing: Error.alreadyPaused)
            return .completion(.failure(Error.alreadyPaused))
        }
        isRunning = false
        continuation.resume()
        return .none
    }

    mutating func resume(
        _ continuation: UnsafeContinuation<Void, Swift.Error>
    ) async throws -> Reducer<Self, Action>.Effect {
        guard let _ = cancellable else {
            continuation.resume(throwing: Error.disconnected)
            return .completion(.failure(Error.disconnected))
        }
        guard !isRunning else {
            continuation.resume(throwing: Error.alreadyResumed)
            return .completion(.failure(Error.alreadyResumed))
        }
        isRunning = true
        upstreamContinuation?.resume(returning: .more)
        continuation.resume()
        return .none
    }

    mutating func disconnect(
        _ continuation: UnsafeContinuation<Void, Swift.Error>
    ) async throws -> Reducer<Self, Action>.Effect {
        guard let _ = cancellable else {
            continuation.resume(throwing: Error.alreadyDisconnected)
            return .completion(.failure(Error.alreadyDisconnected))
        }
        isRunning = false
        upstreamContinuation?.resume(returning: .done)
        continuation.resume()
        return .completion(.exit)
    }

    mutating func distribute(
        _ action: DistributorState<Output>.Action
    ) async throws -> Reducer<Self, Action>.Effect {
        switch try await distributor.reduce(action: action) {
            case .none:
                return .none
            case .published(_):
                return .none // FIXME: Need to handle this
            case let .completion(completion):
                switch completion {
                    case .finished:
                        return .completion(.finished)
                    case .exit:
                        return .completion(.exit)
                    case let .failure(error):
                        return .completion(.failure(error))
                    case .cancel:
                        return .completion(.cancel)
                }
        }
    }
}
