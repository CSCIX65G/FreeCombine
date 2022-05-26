//
//  Zip.swift
//  
//
//  Created by Van Simmons on 3/16/22.
//
struct ZipState<Left: Sendable, Right: Sendable>: CombinatorState {
    typealias CombinatorAction = Self.Action
    enum Action {
        case setLeft(AsyncStream<Left>.Result, UnsafeContinuation<Demand, Swift.Error>)
        case setRight(AsyncStream<Right>.Result, UnsafeContinuation<Demand, Swift.Error>)
    }

    let channel: Channel<ZipState<Left, Right>.Action>
    let downstream: (AsyncStream<(Left, Right)>.Result) async throws -> Demand
    let leftCancellable: Cancellable<Demand>
    let rightCancellable: Cancellable<Demand>

    var mostRecentDemand: Demand
    var left: (value: Left, continuation: UnsafeContinuation<Demand, Swift.Error>)? = .none
    var right: (value: Right, continuation: UnsafeContinuation<Demand, Swift.Error>)? = .none

    init(
        channel: Channel<ZipState<Left, Right>.Action>,
        downstream: @escaping (AsyncStream<(Left, Right)>.Result) async throws -> Demand,
        mostRecentDemand: Demand = .more,
        left: Publisher<Left>,
        right: Publisher<Right>
    ) async {
        self.channel = channel
        self.downstream = downstream
        self.mostRecentDemand = mostRecentDemand
        self.leftCancellable = await channel.consume(publisher: left, using: ZipState<Left, Right>.Action.setLeft)
        self.rightCancellable = await channel.consume(publisher: right, using: ZipState<Left, Right>.Action.setRight)
    }

    static func create(
        mostRecentDemand: Demand = .more,
        left: Publisher<Left>,
        right: Publisher<Right>
    ) -> (@escaping (AsyncStream<(Left, Right)>.Result) async throws -> Demand) -> (Channel<ZipState<Left, Right>.Action>) async -> Self {
        { downstream in { channel in
            await .init(channel: channel, downstream: downstream, left: left, right: right)
        } }
    }

    static func complete(state: inout Self, completion: Reducer<Self, Self.Action>.Completion) async -> Void {
        switch completion {
            case let .cancel(state):
                state.leftCancellable.cancel()
                state.left?.continuation.resume(throwing: PublisherError.cancelled)
                _ = await state.leftCancellable.task.result
                state.rightCancellable.cancel()
                state.right?.continuation.resume(throwing: PublisherError.cancelled)
                _ = await state.rightCancellable.task.result
                state.channel.finish()
            default:
                ()
        }
    }

    static func reduce(`self`: inout Self, action: Self.Action) async throws -> Reducer<Self, Action>.Effect {
        do {
            guard !Task.isCancelled else {
                _ = try await `self`.downstream(.completion(.failure(PublisherError.cancelled)))
                throw PublisherError.cancelled
            }
            return try await `self`.reduce(action: action)
        } catch {
            await complete(state: &`self`, completion: .cancel(`self`))
            throw error
        }
    }

    private mutating func reduce(
        action: Self.Action
    ) async throws -> Reducer<Self, Action>.Effect {
        switch action {
            case let .setLeft(leftResult, leftContinuation):
                if mostRecentDemand == .done { leftContinuation.resume(returning: .done) }
                else { return try await handleLeft(leftResult, leftContinuation) }
            case let .setRight(rightResult, rightContinuation):
                if mostRecentDemand == .done { rightContinuation.resume(returning: .done) }
                else { return try await handleRight(rightResult, rightContinuation) }
        }
        return .none
    }

    private mutating func handleLeft(
        _ leftResult: AsyncStream<Left>.Result,
        _ leftContinuation: UnsafeContinuation<Demand, Error>
    ) async throws -> Reducer<Self, Action>.Effect {
        guard left == nil else {
            throw PublisherError.internalError
        }
        switch leftResult {
            case let .value((value)):
                left = (value, leftContinuation)
                if let right = right {
                    guard !Task.isCancelled else {
                        leftCancellable.cancel()
                        rightCancellable.cancel()
                        _ = try await downstream(.completion(.failure(PublisherError.cancelled)))
                        throw PublisherError.cancelled
                    }
                    mostRecentDemand = try await downstream(.value((value, right.value)))
                    try resume(returning: mostRecentDemand)
                }
            case let .completion(finalState) :
                try await terminate(with: finalState)
        }
        return .none
    }

    private mutating func handleRight(
        _ rightResult: AsyncStream<Right>.Result,
        _ rightContinuation: UnsafeContinuation<Demand, Error>
    ) async throws -> Reducer<Self, Self.Action>.Effect {
        guard right == nil else {
            throw PublisherError.internalError
        }
        switch rightResult {
            case let .value((value)):
                right = (value, rightContinuation)
                if let left = left {
                    guard !Task.isCancelled else {
                        leftCancellable.cancel()
                        rightCancellable.cancel()
                        _ = try await downstream(.completion(.failure(PublisherError.cancelled)))
                        throw PublisherError.cancelled
                    }
                    mostRecentDemand = try await downstream(.value((left.value, value)))
                    try resume(returning: mostRecentDemand)
                }
            case let .completion(finalState) :
                try await terminate(with: finalState)
        }
        return .none
    }

    private mutating func resume(returning demand: Demand) throws {
        if let left = left { left.continuation.resume(returning: demand) }
        else if demand == .done { leftCancellable.cancel() }
        left = .none

        if let right = right { right.continuation.resume(returning: demand) }
        else if demand == .done { rightCancellable.cancel() }
        right = .none

        if demand == .done {
            throw PublisherError.completed
        }
    }

    private mutating func terminate(with completion: Completion) async throws -> Void {
        mostRecentDemand = try await downstream(.completion(completion))
        try resume(returning: mostRecentDemand)
    }
}
