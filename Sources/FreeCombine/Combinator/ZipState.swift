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

    let downstream: (AsyncStream<(Left, Right)>.Result) async throws -> Demand
    let leftCancellable: Task<Demand, Swift.Error>
    let rightCancellable: Task<Demand, Swift.Error>

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

    static func complete(state: Self, completion: StateTask<Self, Self.Action>.Completion) async -> Void {
        switch completion {
            case let .cancel(state):
                state.leftCancellable.cancel()
                state.left?.continuation.resume(throwing: StateTaskError.cancelled)
                _ = await state.leftCancellable.result
                state.rightCancellable.cancel()
                state.right?.continuation.resume(throwing: StateTaskError.cancelled)
                _ = await state.rightCancellable.result
            default:
                ()
        }
    }

    static func reduce(`self`: inout Self, action: Self.Action) async throws -> Void {
        do {
            try await `self`.reduce(action: action)
        } catch {
            await complete(state: `self`, completion: .cancel(`self`))
            throw error
        }
    }

    private mutating func reduce(
        action: Self.Action
    ) async throws -> Void {
        switch action {
            case let .setLeft(leftResult, leftContinuation):
                return mostRecentDemand == .done ? leftContinuation.resume(returning: .done)
                : try await handleLeft(leftResult, leftContinuation)
            case let .setRight(rightResult, rightContinuation):
                return mostRecentDemand == .done ? rightContinuation.resume(returning: .done)
                : try await handleRight(rightResult, rightContinuation)
        }
    }

    private mutating func handleLeft(
        _ leftResult: AsyncStream<Left>.Result,
        _ leftContinuation: UnsafeContinuation<Demand, Error>
    ) async throws -> Void {
        guard left == nil else {
            throw PublisherError.internalError
        }
        switch leftResult {
            case let .value((value)):
                left = (value, leftContinuation)
                if let right = right {
                    mostRecentDemand = try await downstream(.value((value, right.value)))
                    try resume(returning: mostRecentDemand)
                }
            case let .completion(finalState) :
                try await terminate(with: finalState); return
        }
    }

    private mutating func handleRight(
        _ rightResult: AsyncStream<Right>.Result,
        _ rightContinuation: UnsafeContinuation<Demand, Error>
    ) async throws -> Void {
        guard right == nil else {
            throw PublisherError.internalError
        }
        switch rightResult {
            case let .value((value)):
                right = (value, rightContinuation)
                if let left = left{
                    mostRecentDemand = try await downstream(.value((left.value, value)))
                    try resume(returning: mostRecentDemand)
                }
            case let .completion(finalState) :
                try await terminate(with: finalState); return
        }
    }

    private mutating func resume(returning demand: Demand) throws {
        if let left = left { left.continuation.resume(returning: demand) }
        else if demand == .done { leftCancellable.cancel() }
        left = .none

        if let right = right { right.continuation.resume(returning: demand) }
        else if demand == .done { rightCancellable.cancel() }
        right = .none

        if demand == .done { throw StateTaskError.completed }
    }

    private mutating func terminate(with completion: Completion) async throws -> Void {
        mostRecentDemand = try await downstream(.completion(completion))
        try resume(returning: mostRecentDemand)
    }
}
