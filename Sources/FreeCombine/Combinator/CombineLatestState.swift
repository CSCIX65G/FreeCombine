//
//  CombineLatestState.swift
//  
//
//  Created by Van Simmons on 6/4/22.
//
struct CombineLatestState<Left: Sendable, Right: Sendable> {
    typealias CombinatorAction = Self.Action
    enum Action {
        case setLeft(AsyncStream<Left>.Result, UnsafeContinuation<Demand, Swift.Error>)
        case setRight(AsyncStream<Right>.Result, UnsafeContinuation<Demand, Swift.Error>)
    }

    let downstream: (AsyncStream<(Left?, Right?)>.Result) async throws -> Demand
    let leftCancellable: Cancellable<Demand>
    let rightCancellable: Cancellable<Demand>

    var mostRecentDemand: Demand
    var left: (value: Left?, continuation: UnsafeContinuation<Demand, Swift.Error>)? = .none
    var right: (value: Right?, continuation: UnsafeContinuation<Demand, Swift.Error>)? = .none
    var leftComplete = false
    var rightComplete = false

    init(
        channel: Channel<CombineLatestState<Left, Right>.Action>,
        downstream: @escaping (AsyncStream<(Left?, Right?)>.Result) async throws -> Demand,
        mostRecentDemand: Demand = .more,
        left: Publisher<Left>,
        right: Publisher<Right>
    ) async {
        self.downstream = downstream
        self.mostRecentDemand = mostRecentDemand
        self.leftCancellable = await channel.consume(publisher: left, using: CombineLatestState<Left, Right>.Action.setLeft)
        self.rightCancellable = await channel.consume(publisher: right, using: CombineLatestState<Left, Right>.Action.setRight)
    }

    static func create(
        left: Publisher<Left>,
        right: Publisher<Right>
    ) -> (@escaping (AsyncStream<(Left?, Right?)>.Result) async throws -> Demand) -> (Channel<CombineLatestState<Left, Right>.Action>) async -> Self {
        { downstream in { channel in
            await .init(channel: channel, downstream: downstream, left: left, right: right)
        } }
    }

    static func complete(state: inout Self, completion: Reducer<Self, Self.Action>.Completion) async -> Void {
        state.left?.continuation.resume(returning: .done)
        state.leftCancellable.cancel()
        state.right?.continuation.resume(returning: .done)
        state.rightCancellable.cancel()
        switch completion {
            case .cancel:
                _ = try? await state.downstream(.completion(.cancelled))
            case .exit, .termination:
                _ = try? await state.downstream(.completion(.finished))
            case let .failure(error):
                _ = try? await state.downstream(.completion(.failure(error)))
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
        _ leftContinuation: UnsafeContinuation<Demand, Error>
    ) async throws -> Reducer<Self, Action>.Effect {
        switch leftResult {
            case let .value((value)):
                left = (value, leftContinuation)
                guard !Task.isCancelled else {
                    leftContinuation.resume(returning: .done)
                    return .completion(.cancel)
                }
                mostRecentDemand = try await downstream(.value((value, right?.value)))
                leftContinuation.resume(returning: mostRecentDemand)
                return .none
            case .completion(_):
                leftComplete = true
                return leftComplete && rightComplete ? .completion(.exit) : .none
        }
    }

    private mutating func handleRight(
        _ rightResult: AsyncStream<Right>.Result,
        _ rightContinuation: UnsafeContinuation<Demand, Error>
    ) async throws -> Reducer<Self, Self.Action>.Effect {
        switch rightResult {
            case let .value((value)):
                right = (value, rightContinuation)
                guard !Task.isCancelled else {
                    rightContinuation.resume(returning: .done)
                    return .completion(.cancel)
                }
                mostRecentDemand = try await downstream(.value((left?.value, value)))
                rightContinuation.resume(returning: mostRecentDemand)
                return .none
            case .completion(_) :
                rightComplete = true
                return leftComplete && rightComplete ? .completion(.exit) : .none
        }
    }
}
