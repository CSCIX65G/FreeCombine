//
//  Zip.swift
//  
//
//  Created by Van Simmons on 3/16/22.
//
struct ZipState<Left: Sendable, Right: Sendable> {
    typealias CombinatorAction = Self.Action
    enum Action {
        case setLeft(AsyncStream<Left>.Result, Resumption<Demand>)
        case setRight(AsyncStream<Right>.Result, Resumption<Demand>)
    }

    let downstream: (AsyncStream<(Left, Right)>.Result) async throws -> Demand
    let leftCancellable: Cancellable<Demand>
    let rightCancellable: Cancellable<Demand>

    var mostRecentDemand: Demand = .more
    var left: (value: Left, resumption: Resumption<Demand>)? = .none
    var right: (value: Right, resumption: Resumption<Demand>)? = .none

    init(
        channel: Channel<ZipState<Left, Right>.Action>,
        downstream: @escaping (AsyncStream<(Left, Right)>.Result) async throws -> Demand,
        left: Publisher<Left>,
        right: Publisher<Right>
    ) async {
        self.downstream = downstream
        self.leftCancellable = await channel.consume(publisher: left, using: ZipState<Left, Right>.Action.setLeft)
        self.rightCancellable = await channel.consume(publisher: right, using: ZipState<Left, Right>.Action.setRight)
    }

    static func create(
        left: Publisher<Left>,
        right: Publisher<Right>
    ) -> (@escaping (AsyncStream<(Left, Right)>.Result) async throws -> Demand) -> (Channel<ZipState<Left, Right>.Action>) async -> Self {
        { downstream in { channel in
            await .init(channel: channel, downstream: downstream, left: left, right: right)
        } }
    }

    static func complete(state: inout Self, completion: Reducer<Self, Self.Action>.Completion) async -> Void {
        if let left = state.left, left.resumption.hasResumed { state.left?.resumption.resume(returning: .done) }
        state.leftCancellable.cancel()
        if let right = state.right, right.resumption.hasResumed { state.right?.resumption.resume(returning: .done) }
        state.rightCancellable.cancel()
        switch completion {
            case .cancel:
                _ = try? await state.downstream(.completion(.cancelled))
            case .exit, .finished:
                _ = try? await state.downstream(.completion(.finished))
            case let .failure(error):
                _ = try? await state.downstream(.completion(.failure(error)))
        }
    }

    static func dispose(action: Self.Action, completion: Reducer<Self, Self.Action>.Completion) async -> Void {
        switch action {
            case let .setLeft(_, resumption) where !resumption.hasResumed:
                resumption.resume(throwing: PublisherError.cancelled)
            case let .setRight(_, resumption) where !resumption.hasResumed:
                resumption.resume(throwing: PublisherError.cancelled)
            default:
                ()
        }
    }

    static func reduce(`self`: inout Self, action: Self.Action) async throws -> Reducer<Self, Action>.Effect {
        guard !Task.isCancelled else { return .completion(.cancel) }
        return try await `self`.reduce(action: action)
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
        _ leftResumption: Resumption<Demand>
    ) async throws -> Reducer<Self, Action>.Effect {
        guard left == nil else { throw PublisherError.internalError }
        switch leftResult {
            case let .value((value)):
                left = (value, leftResumption)
                if let right = right {
                    mostRecentDemand = try await downstream(.value((value, right.value)))
                    try resume(returning: mostRecentDemand)
                }
                return .none
            case .completion(_):
                if let right = right {
                    right.resumption.resume(returning: .done)
                }
                leftResumption.resume(returning: .done)
                left = .none
                right = .none
                return .completion(.exit)
        }
    }

    private mutating func handleRight(
        _ rightResult: AsyncStream<Right>.Result,
        _ rightResumption: Resumption<Demand>
    ) async throws -> Reducer<Self, Self.Action>.Effect {
        guard right == nil else { throw PublisherError.internalError }
        switch rightResult {
            case let .value((value)):
                right = (value, rightResumption)
                if let left = left {
                    guard !Task.isCancelled else { return .completion(.cancel) }
                    mostRecentDemand = try await downstream(.value((left.value, value)))
                    try resume(returning: mostRecentDemand)
                }
                return .none
            case .completion(_) :
                if let left = left {
                    left.resumption.resume(returning: .done)
                }
                rightResumption.resume(returning: .done)
                left = .none
                right = .none
                return .completion(.exit)
        }
    }

    private mutating func resume(returning demand: Demand) throws {
        if let left = left { left.resumption.resume(returning: demand) }
        else if demand == .done { leftCancellable.cancel() }
        left = .none

        if let right = right { right.resumption.resume(returning: demand) }
        else if demand == .done { rightCancellable.cancel() }
        right = .none
    }
}
