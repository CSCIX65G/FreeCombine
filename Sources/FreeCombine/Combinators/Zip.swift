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
        leftCancellable: Task<Demand, Swift.Error>,
        rightCancellable: Task<Demand, Swift.Error>
    ) {
        self.downstream = downstream
        self.mostRecentDemand = mostRecentDemand
        self.leftCancellable = leftCancellable
        self.rightCancellable = rightCancellable
    }

    mutating func resume(returning demand: Demand) {
        if let left = left { left.continuation.resume(returning: demand) }
        else if demand == .done { leftCancellable.cancel() }
        left = .none

        if let right = right { right.continuation.resume(returning: demand) }
        else if demand == .done { rightCancellable.cancel() }
        right = .none
    }

    mutating func handleLeft(
        _ leftResult: AsyncStream<Left>.Result,
        _ leftContinuation: UnsafeContinuation<Demand, Error>
    ) async throws -> Void {
        guard left == nil else {
            throw StateThread<ZipState<Left, Right>, Self.Action>.Error.internalError
        }
        switch leftResult {
            case let .value((value)):
                left = (value, leftContinuation)
                if let right = right {
                    mostRecentDemand = try await downstream(.value((value, right.value)))
                    resume(returning: mostRecentDemand)
                }
            case .terminated:
                mostRecentDemand = try await downstream(.terminated)
                resume(returning: mostRecentDemand)
            case let .failure(error):
                mostRecentDemand = try await downstream(.failure(error))
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
        switch rightResult {
            case let .value((value)):
                right = (value, rightContinuation)
                if let left = left{
                    // Do not send non-terminal values downstream until cancellables are in place
                    mostRecentDemand = try await downstream(.value((left.value, value)))
                    resume(returning: mostRecentDemand)
                }
            case .terminated:
                mostRecentDemand = try await downstream(.terminated)
                resume(returning: mostRecentDemand)
            case let .failure(error):
                mostRecentDemand = try await downstream(.failure(error))
                resume(returning: mostRecentDemand)
        }
    }

    mutating func reduce(
        action: Self.Action
    ) async throws -> Void {
        switch action {
            case let .setLeft(leftResult, leftContinuation):
                return mostRecentDemand == .done ? leftContinuation.resume(returning: mostRecentDemand)
                    : try await handleLeft(leftResult, leftContinuation)
            case let .setRight(rightResult, rightContinuation):
                return mostRecentDemand == .done ? rightContinuation.resume(returning: mostRecentDemand)
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
            // Construct the zip channel and connect it to downstream
            // If downstream ever returns `.done`, the channel will never send downstream again.
            // Note that this and the subsequent setup calls all `await`
            // Note that buffer size of 3 allows left, right and setTasks to all be in queue
            // at once
            let zipStateThread: StateThread<ZipState<Left, Right>, ZipState<Left, Right>.Action> = await .stateThread(
                initialState: { channel in
                    .init(
                        downstream: downstream,
                        leftCancellable: await channel.consume(
                            publisher: left,
                            using: ZipState<Left, Right>.Action.setLeft
                        ),
                        rightCancellable: await channel.consume(
                            publisher: right,
                            using: ZipState<Left, Right>.Action.setRight
                        )
                    )
                },
                buffering: .bufferingOldest(2),
                operation: ZipState<Left, Right>.reduce
            )

            // Everything is now set up, install the cancellation and tell the outside
            // world to proceed.  External resumption must occur before any returns
            return try await withTaskCancellationHandler(handler: {
                zipStateThread.task.cancel()
                onCancel()
            }) {
                continuation?.resume()
                guard !Task.isCancelled else { throw Publisher<(Left, Right)>.Error.cancelled }
                return try await zipStateThread.task.value.mostRecentDemand
            }
        }
    }
}
