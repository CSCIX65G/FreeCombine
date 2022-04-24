//
//  Zip.swift
//  
//
//  Created by Van Simmons on 3/16/22.
//

fileprivate enum ZipAction<Left: Sendable, Right: Sendable>: SynchronousAction {
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

fileprivate struct ZipState<Left: Sendable, Right: Sendable>: Sendable {
    var downstream: @Sendable (AsyncStream<(Left, Right)>.Result) async throws -> Demand
    var demand: Demand
    var left: (value: Left, continuation: UnsafeContinuation<Demand, Swift.Error>)? = .none
    var leftCancellable: Task<Demand, Swift.Error>? = .none
    var right: (value: Right, continuation: UnsafeContinuation<Demand, Swift.Error>)? = .none
    var rightCancellable: Task<Demand, Swift.Error>? = .none

    init(
        downstream: @Sendable @escaping (AsyncStream<(Left, Right)>.Result) async throws -> Demand,
        demand: Demand = .more
    ) {
        self.downstream = downstream
        self.demand = demand
    }

    mutating func resume(returning demand: Demand) {
        if let left = left {
            left.continuation.resume(returning: demand)
        } else if demand == .done {
            leftCancellable?.cancel()
            leftCancellable = .none
        }
        left = .none

        if let right = right {
            right.continuation.resume(returning: demand)
        } else if demand == .done {
            rightCancellable?.cancel()
            rightCancellable = .none
        }
        right = .none
    }

    mutating func handleLeft(
        _ leftResult: AsyncStream<Left>.Result,
        _ leftContinuation: UnsafeContinuation<Demand, Error>
    ) async throws -> Void {
        guard left == nil else {
            throw StateThread<ZipState<Left, Right>, ZipAction<Left, Right>>.Error.internalError
        }
        switch leftResult {
            case let .value((value)):
                left = (value, leftContinuation)
                if let right = right, rightCancellable != nil {
                    // Do not send non-terminal values downstream until cancellables are in place
                    demand = try await downstream(.value((value, right.value)))
                    resume(returning: demand)
                }
            case .terminated:
                demand = try await downstream(.terminated)
                resume(returning: demand)
            case let .failure(error):
                demand = try await downstream(.failure(error))
                resume(returning: demand)
        }
    }

    mutating func handleRight(
        _ rightResult: AsyncStream<Right>.Result,
        _ rightContinuation: UnsafeContinuation<Demand, Error>
    ) async throws -> Void {
        guard right == nil else {
            throw StateThread<ZipState<Left, Right>, ZipAction<Left, Right>>.Error.internalError
        }
        switch rightResult {
            case let .value((value)):
                right = (value, rightContinuation)
                if let left = left, leftCancellable != nil {
                    // Do not send non-terminal values downstream until cancellables are in place
                    demand = try await downstream(.value((left.value, value)))
                    resume(returning: demand)
                }
            case .terminated:
                demand = try await downstream(.terminated)
                resume(returning: demand)
            case let .failure(error):
                demand = try await downstream(.failure(error))
                resume(returning: demand)
        }
    }

    mutating func handleSetTasks(
        leftTask: Task<Demand, Swift.Error>,
        rightTask: Task<Demand, Swift.Error>,
        continuation: UnsafeContinuation<Demand, Swift.Error>
    ) async throws -> Void {
        leftCancellable = leftTask
        rightCancellable = rightTask
        if let left = left, let right = right {
            demand = try await downstream(.value((left.value, right.value)))
            resume(returning: demand)
        } else if demand == .done {
            leftTask.cancel()
            rightTask.cancel()
        }
        continuation.resume(returning: demand)
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

fileprivate extension StateThread {
    func setTasks<Left, Right>(
        left: Task<Demand, Swift.Error>,
        right: Task<Demand, Swift.Error>,
        _ continuation: UnsafeContinuation<Void, Never>?
    ) async throws -> Demand where State == ZipState<Left, Right>, Action ==  ZipAction<Left, Right> {
        try await withUnsafeThrowingContinuation { dContinuation in
            guard case .enqueued = self.channel.yield(.setTasks(left: left, right: right, dContinuation)) else {
                self.channel.finish()
                left.cancel()
                right.cancel()
                self.cancel()
                continuation?.resume()
                dContinuation.resume(throwing: StateThread<ZipState<Left, Right>, ZipAction<Left, Right>>.Error.internalError)
                return
            }
        }
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
            // If downstream ever returns `.done` the channel will never send downstream again.
            // Note that this and subsequent calls all `await`
            let stateThread: StateThread<ZipState<Left, Right>, ZipAction<Left, Right>> = await .stateThread(
                initialState: .init(downstream: downstream, demand: .more),
                buffering: .bufferingOldest(3),
                operation: ZipState<Left, Right>.reduce
            )

            // Construct the left upstream task by providing a sink to the left publisher
            let leftTask = await stateThread.consume(publisher: left, using: ZipAction<Left, Right>.setLeft)

            // Construct the right upstream task by providing a sink to the right publisher
            let rightTask = await stateThread.consume(publisher: right, using: ZipAction<Left, Right>.setRight)

            // Tell the zip channel how to cancel the upstream tasks if necessary
            // allow any values from upstream to be sent downstream
            // if either of the upstream publishers completed before we could
            // set the cancellables in the downstream state, this returns .done
            // It should never throw
            let demand: Demand = try await stateThread.setTasks(left: leftTask, right: rightTask, continuation)

            // Compose the entire cancellation now that the tasks are running and communicating
            // Note the subtasks cannot be cancelled externally bc they are never visible
            // outside this function.  They can only be cancelled as a side effect of
            // cancelling this publisher
            let cancellation: @Sendable () -> Void = {
                stateThread.task.cancel()
                leftTask.cancel()
                rightTask.cancel()
                onCancel()
            }

            // Everything is now set up, install the cancellation and tell the outside
            // world to proceed.
            return try await withTaskCancellationHandler(handler: cancellation) {
                continuation?.resume()
                guard case .more = demand else {
                    stateThread.finish()
                    return .done
                }
                guard !Task.isCancelled else {
                    throw Publisher<(Left, Right)>.Error.cancelled
                }
                return try await stateThread.task.value.demand
            }
        }
    }
}
