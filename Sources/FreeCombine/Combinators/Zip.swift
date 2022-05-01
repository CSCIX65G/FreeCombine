//
//  Zip.swift
//  
//
//  Created by Van Simmons on 3/16/22.
//

fileprivate struct ZipState<Left: Sendable, Right: Sendable> {
    enum Action {
        case setLeft(AsyncStream<Left>.Result, UnsafeContinuation<Demand, Swift.Error>)
        case setRight(AsyncStream<Right>.Result, UnsafeContinuation<Demand, Swift.Error>)
    }

    var downstream: (AsyncStream<(Left, Right)>.Result) async throws -> Demand
    var mostRecentDemand: Demand
    var leftCancellable: Task<Demand, Swift.Error>
    var rightCancellable: Task<Demand, Swift.Error>

    var left: (value: Left, continuation: UnsafeContinuation<Demand, Swift.Error>)? = .none
    var right: (value: Right, continuation: UnsafeContinuation<Demand, Swift.Error>)? = .none

    init(
        downstream: @escaping (AsyncStream<(Left, Right)>.Result) async throws -> Demand,
        mostRecentDemand: Demand = .more,
        channel: Channel<ZipState<Left, Right>.Action>,
        left: Publisher<Left>,
        right: Publisher<Right>
    ) async {
        self.downstream = downstream
        self.mostRecentDemand = mostRecentDemand
        self.leftCancellable = await channel.consume(publisher: left, using: ZipState<Left, Right>.Action.setLeft)
        self.rightCancellable = await channel.consume(publisher: right, using: ZipState<Left, Right>.Action.setRight)
    }

    mutating func resume(returning demand: Demand) {
        if let left = left { left.continuation.resume(returning: demand) }
        else if demand == .done { leftCancellable.cancel() }
        left = .none

        if let right = right { right.continuation.resume(returning: demand) }
        else if demand == .done { rightCancellable.cancel() }
        right = .none
    }

    mutating func terminate(with completion: AsyncStream<Left>.Result) async throws -> Void {
        var finalState = AsyncStream<(Left, Right)>.Result.terminated
        if case let .failure(error) = completion { finalState = .failure(error) }
        mostRecentDemand = try await downstream(finalState)
        resume(returning: mostRecentDemand)
    }
    mutating func terminate(with completion: AsyncStream<Right>.Result) async throws -> Void {
        var finalState = AsyncStream<(Left, Right)>.Result.terminated
        if case let .failure(error) = completion { finalState = .failure(error) }
        mostRecentDemand = try await downstream(finalState)
        resume(returning: mostRecentDemand)
    }

    mutating func handleLeft(
        _ leftResult: AsyncStream<Left>.Result,
        _ leftContinuation: UnsafeContinuation<Demand, Error>
    ) async throws -> Void {
        guard left == nil else {
            throw StateThread<ZipState<Left, Right>, Self.Action>.Error.internalError
        }
        guard case let .value((value)) = leftResult else {
            try await terminate(with: leftResult); return
        }
        left = (value, leftContinuation)
        if let right = right {
            mostRecentDemand = try await downstream(.value((value, right.value)))
            resume(returning: mostRecentDemand)
        }
    }

    mutating func handleRight(
        _ rightResult: AsyncStream<Right>.Result,
        _ rightContinuation: UnsafeContinuation<Demand, Error>
    ) async throws -> Void {
        guard right == nil else {
            throw StateThread<ZipState<Left, Right>, Self.Action>.Error.internalError
        }
        guard case let .value((value)) = rightResult else {
            try await terminate(with: rightResult); return
        }
        right = (value, rightContinuation)
        if let left = left{
            mostRecentDemand = try await downstream(.value((left.value, value)))
            resume(returning: mostRecentDemand)
        }
    }

    mutating func reduce(
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

    static func reduce(`self`: inout Self, action: Self.Action) async throws -> Void {
        try await `self`.reduce(action: action)
    }
}

public func zip<Left, Right>(
    onCancel: @Sendable @escaping () -> Void = { },
    _ left: Publisher<Left>,
    _ right: Publisher<Right>
) -> Publisher<(Left, Right)> {
    .init { continuation, downstream in
        .init {
            let zipStateThread: StateThread<ZipState<Left, Right>, ZipState<Left, Right>.Action> = await .stateThread(
                initialState: { await .init(downstream: downstream, channel: $0, left: left, right: right) },
                buffering: .bufferingOldest(2),
                onCompletion: { completion in switch completion {
                    case let .cancel(state):
                        state.leftCancellable.cancel()
                        state.rightCancellable.cancel()
                    default:
                        ()
                } },
                operation: ZipState<Left, Right>.reduce
            )

            return try await withTaskCancellationHandler(handler: {
                zipStateThread.cancel()
                onCancel()
            }) {
                continuation?.resume()
                guard !Task.isCancelled else { throw Publisher<(Left, Right)>.Error.cancelled }
                return try await zipStateThread.finalState.mostRecentDemand
            }
        }
    }
}
