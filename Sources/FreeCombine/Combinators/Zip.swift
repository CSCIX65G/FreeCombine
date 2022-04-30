//
//  Zip.swift
//  
//
//  Created by Van Simmons on 3/16/22.
//

fileprivate struct ZipState<Left: Sendable, Right: Sendable> {
    enum Action: SynchronousAction {
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

    var downstream: (AsyncStream<(Left, Right)>.Result) async throws -> Demand
    var mostRecentDemand: Demand
    var left: (value: Left, continuation: UnsafeContinuation<Demand, Swift.Error>)? = .none
    var leftCancellable: Task<Demand, Swift.Error>? = .none
    var right: (value: Right, continuation: UnsafeContinuation<Demand, Swift.Error>)? = .none
    var rightCancellable: Task<Demand, Swift.Error>? = .none

    init(
        downstream: @escaping (AsyncStream<(Left, Right)>.Result) async throws -> Demand,
        demand: Demand = .more
    ) {
        self.downstream = downstream
        self.mostRecentDemand = demand
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
            throw StateThread<ZipState<Left, Right>, Self.Action>.Error.internalError
        }
        switch leftResult {
            case let .value((value)):
                left = (value, leftContinuation)
                if let right = right, rightCancellable != nil {
                    // Do not send non-terminal values downstream until cancellables are in place
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
                if let left = left, leftCancellable != nil {
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

    mutating func handleSetTasks(
        leftTask: Task<Demand, Swift.Error>,
        rightTask: Task<Demand, Swift.Error>,
        continuation: UnsafeContinuation<Demand, Swift.Error>
    ) async throws -> Void {
        leftCancellable = leftTask
        rightCancellable = rightTask
        if let left = left, let right = right {
            mostRecentDemand = try await downstream(.value((left.value, right.value)))
            resume(returning: mostRecentDemand)
        } else if mostRecentDemand == .done {
            leftTask.cancel()
            rightTask.cancel()
        }
        continuation.resume(returning: mostRecentDemand)
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
            case let .setTasks(left: leftTask, right: rightTask, continuation):
                return mostRecentDemand == .done ? continuation.resume(returning: mostRecentDemand)
                    : try await handleSetTasks(leftTask: leftTask, rightTask: rightTask, continuation: continuation)
        }
    }

    static func reduce(`self`: inout Self, action: Self.Action) async throws -> Void {
        try await `self`.reduce(action: action)
    }
}

fileprivate extension StateThread {
    func setTasks<Left, Right>(
        left: Task<Demand, Swift.Error>,
        right: Task<Demand, Swift.Error>,
        _ continuation: UnsafeContinuation<Void, Never>?
    ) async throws -> Demand where State == ZipState<Left, Right>, Action == ZipState<Left, Right>.Action {
        try await withUnsafeThrowingContinuation { dContinuation in
            guard case .enqueued = self.channel.yield(.setTasks(left: left, right: right, dContinuation)) else {
                fatalError("Failed to enqueue zip upstream tasks")
            }
        }
    }
}

public func zip<Left, Right>(
    onCancel: @Sendable @escaping () -> Void = { },
    _ left: Publisher<Left>,
    _ right: Publisher<Right>
) -> Publisher<(Left, Right)> {
    typealias State = ZipState<Left, Right>
    typealias Action = ZipState<Left, Right>.Action
    return .init { continuation, downstream in
        .init {
            // Construct the zip channel and connect it to downstream
            // If downstream ever returns `.done`, the channel will never send downstream again.
            // Note that this and the subsequent setup calls all `await`
            // Note that buffer size of 3 allows left, right and setTasks to all be in queue
            // at once
            let zipStateThread: StateThread<State, Action> = await .stateThread(
                initialState: .init(downstream: downstream, demand: .more),
                buffering: .bufferingOldest(3),
                operation: ZipState<Left, Right>.reduce
            )

            // Construct the left upstream task by providing a sink to the left publisher
            let leftTask = await zipStateThread.consume(publisher: left, using: Action.setLeft)

            // Construct the right upstream task by providing a sink to the right publisher
            let rightTask = await zipStateThread.consume(publisher: right, using: Action.setRight)

            // Tell the zip channel how to cancel the upstream tasks if necessary
            // This will allow any values from upstream to start being sent downstream
            // if either of the upstream publishers completed before we could
            // set the cancellables in the downstream state, this returns .done
            let demand: Demand = try await zipStateThread.setTasks(left: leftTask, right: rightTask, continuation)

            // Compose the entire cancellation now that the tasks are running and communicating
            // Note the subtasks cannot be cancelled externally bc they are never visible
            // outside this function.  They can only be cancelled as a side effect of
            // cancelling this publisher
            let cancellation: @Sendable () -> Void = {
                zipStateThread.task.cancel()
                leftTask.cancel()
                rightTask.cancel()
                onCancel()
            }

            // Everything is now set up, install the cancellation and tell the outside
            // world to proceed.  External resumption must occur before any returns
            return try await withTaskCancellationHandler(handler: cancellation) {
                continuation?.resume()
                guard case .more = demand else { zipStateThread.finish(); return .done }
                guard !Task.isCancelled else { throw Publisher<(Left, Right)>.Error.cancelled }
                return try await zipStateThread.task.value.mostRecentDemand
            }
        }
    }
}
