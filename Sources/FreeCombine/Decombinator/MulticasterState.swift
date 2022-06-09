//
//  MulticasterState.swift
//  
//
//  Created by Van Simmons on 6/5/22.
//

public struct MulticasterState<Output: Sendable> {
    public enum Action: Sendable {
        case connect(UnsafeContinuation<Void, Swift.Error>)
        case pause(UnsafeContinuation<Void, Swift.Error>)
        case resume(UnsafeContinuation<Void, Swift.Error>)
        case disconnect(UnsafeContinuation<Void, Swift.Error>)
        case distribute(DistributorState<Output>.Action)
    }

    public enum Error: Swift.Error {
        case alreadyConnected
        case alreadyDisconnected
        case disconnected
        case alreadyPaused
        case alreadyResumed
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
            await withUnsafeContinuation { continuation in
                channel.yield(.distribute(.receive(r, continuation)))
            }
            return .more
        }
    }

    static func create(
        upstream: Publisher<Output>
    ) -> (Channel<MulticasterState<Output>.Action>) -> Self {
        { channel in .init(upstream: upstream, channel: channel) }
    }

    static func complete(state: inout Self, completion: Reducer<Self, Self.Action>.Completion) async -> Void {
        switch completion {
            case .finished:
                await state.distributor.process(currentRepeaters: state.distributor.repeaters, with: .completion(.finished))
            case .exit:
                fatalError("Multicaster should never exit")
            case let .failure(error):
                await state.distributor.process(currentRepeaters: state.distributor.repeaters, with: .completion(.failure(error)))
            case .cancel:
                await state.distributor.process(currentRepeaters: state.distributor.repeaters, with: .completion(.cancelled))
        }
        for (_, repeater) in state.distributor.repeaters {
            repeater.finish()
        }
        state.distributor.repeaters.removeAll()
    }

    static func reduce(`self`: inout Self, action: Self.Action) async throws -> Reducer<Self, Action>.Effect {
        try await `self`.reduce(action: action)
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
            continuation.resume(throwing: Error.alreadyConnected)
            return .completion(.failure(Error.alreadyConnected))
        }
        cancellable = await upstream.sink(downstream)
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
