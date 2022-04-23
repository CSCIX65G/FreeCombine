//
//  Zip.swift
//  
//
//  Created by Van Simmons on 3/16/22.
//

fileprivate enum ZipAction<Left, Right>: SynchronousAction {
    case setLeft(AsyncStream<Left>.Result, UnsafeContinuation<Demand, Swift.Error>)
    case setRight(AsyncStream<Right>.Result, UnsafeContinuation<Demand, Swift.Error>)
    case setTasks(left: Task<Demand, Swift.Error>, right: Task<Demand, Swift.Error>, UnsafeContinuation<Demand, Swift.Error>)

    typealias State = Demand
    var continuation: UnsafeContinuation<Demand, Error> {
        switch self {
            case let .setLeft(_, continuation): return continuation
            case let .setRight(_, continuation): return continuation
            case let .setTasks(left: _, right: _, continuation): return continuation
        }
    }
}

fileprivate struct ZipState<Left, Right> {
    var downstream: (AsyncStream<(Left, Right)>.Result) async throws -> Demand
    var demand: Demand
    var left: (value: Left, continuation: UnsafeContinuation<Demand, Swift.Error>)? = .none
    var leftCancellable: Task<Demand, Swift.Error>? = .none
    var right: (value: Right, continuation: UnsafeContinuation<Demand, Swift.Error>)? = .none
    var rightCancellable: Task<Demand, Swift.Error>? = .none

    init(
        downstream: @escaping (AsyncStream<(Left, Right)>.Result) async throws -> Demand,
        demand: Demand = .more
    ) {
        self.downstream = downstream
        self.demand = demand
    }

    mutating func resume(returning demand: Demand) {
        left?.continuation.resume(returning: demand)
        left = .none

        right?.continuation.resume(returning: demand)
        right = .none
    }

    mutating func handleLeft(
        _ leftResult: AsyncStream<Left>.Result,
        _ leftContinuation: UnsafeContinuation<Demand, Error>
    ) async throws -> Void {
        guard left == nil else {
            throw StatefulChannel<ZipState<Left, Right>, ZipAction<Left, Right>>.Error.internalError
        }
        switch leftResult {
            case let .value((value)):
                left = (value, leftContinuation)
                if let right = right {
                    resume(returning: try await downstream(.value((value, right.value))))
                }
            case .terminated:
                demand = try await downstream(.terminated)
                leftContinuation.resume(returning: demand)
                leftCancellable = .none
                if let right = right {
                    right.continuation.resume(returning: demand)
                    rightCancellable = .none
                } else if let rightCancellable = rightCancellable {
                    rightCancellable.cancel()
                }
            case let .failure(error):
                demand = try await downstream(.failure(error))
                leftContinuation.resume(returning: demand)
                leftCancellable = .none
                if let right = right {
                    right.continuation.resume(returning: demand)
                    rightCancellable = .none
                } else if let rightCancellable = rightCancellable {
                    rightCancellable.cancel()
                }
        }
        self.right = .none
    }

    mutating func handleRight(
        _ rightResult: AsyncStream<Right>.Result,
        _ rightContinuation: UnsafeContinuation<Demand, Error>
    ) async throws -> Void {
        guard right == nil else { throw StatefulChannel<ZipState<Left, Right>, ZipAction<Left, Right>>.Error.internalError }
        switch rightResult {
            case let .value((value)):
                if let left = left {
                    demand = try await downstream(.value((left.value, value)))
                    rightContinuation.resume(returning: demand)
                    left.continuation.resume(returning: demand)
                } else {
                    right = (value, rightContinuation)
                }
            case .terminated:
                demand = try await downstream(.terminated)
                rightContinuation.resume(returning: demand)
                if let left = left {
                    left.continuation.resume(returning: demand)
                } else if let leftCancellable = leftCancellable {
                    leftCancellable.cancel()
                }
            case let .failure(error):
                demand = try await downstream(.failure(error))
                rightContinuation.resume(returning: demand)
                if let left = left {
                    left.continuation.resume(returning: demand)
                } else if let leftCancellable = leftCancellable {
                    leftCancellable.cancel()
                }
        }
        self.left = .none
    }

    mutating func handleSetTasks(
        leftTask: Task<Demand, Swift.Error>,
        rightTask: Task<Demand, Swift.Error>,
        continuation: UnsafeContinuation<Demand, Swift.Error>
    ) async throws -> Void {
        guard .more == demand else {
            leftCancellable?.cancel()
            rightCancellable?.cancel()
            continuation.resume(returning: .done)
            demand = .done
            return
        }
        leftCancellable = leftTask
        rightCancellable = rightTask
        demand = .more
        continuation.resume(returning: .more)
    }

    mutating func reduce(
        action: ZipAction<Left, Right>
    ) async throws -> Void {
        switch action {
            case let .setLeft(leftResult, leftContinuation):
                return demand == .done ? leftContinuation.resume(returning: demand)
                    : try await handleLeft(leftResult, leftContinuation)
            case let .setRight(rightResult, rightContinuation):
                return demand == .done ? rightContinuation.resume(returning: demand)
                    : try await handleRight(rightResult, rightContinuation)
            case let .setTasks(left: leftTask, right: rightTask, continuation):
                return demand == .done ? continuation.resume(returning: demand)
                    : try await handleSetTasks(leftTask: leftTask, rightTask: rightTask, continuation: continuation)
        }
    }

    static func reduce(`self`: inout Self, action: ZipAction<Left, Right>) async throws -> Void {
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
            let channel: StatefulChannel<ZipState<Left, Right>, ZipAction<Left, Right>> = await .channel(
                initialState: .init(downstream: downstream, demand: .more),
                buffering: .bufferingOldest(3),
                operation: ZipState<Left, Right>.reduce
            )

            // Construct the left upstream task by providing a sink to the left publisher
            let leftTask = await channel.consume(publisher: left, using: ZipAction<Left, Right>.setLeft)

            // Construct the right upstream task by providing a sink to the right publisher
            let rightTask = await channel.consume(publisher: right, using: ZipAction<Left, Right>.setRight)

            // Compose the entire cancellation now that the tasks are running and communicating
            // Note the subtasks cannot be cancelled externally bc they are never visible
            // outside this function.  They can only be cancelled as a side effect of
            // cancelling this publisher
            let cancellation: @Sendable () -> Void = {
                channel.task.cancel()
                leftTask.cancel()
                rightTask.cancel()
                onCancel()
            }

            // Tell the zip channel how to cancel the upstream tasks if necessary
            // verify that neither of the upstream publishers completed before we could
            // set these
            let demand: Demand = try await withUnsafeThrowingContinuation { dContinuation in
                guard case .enqueued = channel.yield(
                    .setTasks(left: leftTask, right: rightTask, dContinuation)
                ) else {
                    // This means that we are not processing in the zipChannel and it is bad
                    // we have to cancel everything, tell the outside world and throw from here.
                    channel.finish()
                    cancellation()
                    continuation?.resume()
                    dContinuation.resume(throwing: StatefulChannel<ZipState<Left, Right>, ZipAction<Left, Right>>.Error.internalError)
                    return
                }
            }

            // Everything is now setup, install the cancellation and tell the outside
            // world to proceed.
            return try await withTaskCancellationHandler(handler: cancellation) {
                continuation?.resume()
                // This means that left or right sent a value of done before the .setTasks call
                guard case .more = demand else {
                    channel.finish()
                    return .done
                }
                guard !Task.isCancelled else {
                    throw Publisher<(Left, Right)>.Error.cancelled
                }
                return try await channel.task.value.demand
            }
        }
    }
}
