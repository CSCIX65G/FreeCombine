//
//  Zip.swift
//  
//
//  Created by Van Simmons on 3/16/22.
//

fileprivate enum ZipError: Error {
    case internalError
}

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
    var shouldCancelLeft = false
    var shouldCancelRight = false
    var left: (Left, UnsafeContinuation<Demand, Swift.Error>)? = .none
    var leftCancellable: Task<Demand, Swift.Error>? = .none
    var right: (Right, UnsafeContinuation<Demand, Swift.Error>)? = .none
    var rightCancellable: Task<Demand, Swift.Error>? = .none

    init(
        downstream: @escaping (AsyncStream<(Left, Right)>.Result) async throws -> Demand,
        demand: Demand = .more
    ) {
        self.downstream = downstream
        self.demand = demand
    }

    mutating func handleLeft(
        _ leftResult: AsyncStream<Left>.Result,
        _ leftContinuation: UnsafeContinuation<Demand, Error>
    ) async throws -> Void {
        switch leftResult {
            case let .value(leftValue):
                let (value) = leftValue
                if let right = right {
                    demand = try await downstream(.value((value, right.0)))
                    leftContinuation.resume(returning: demand)
                    right.1.resume(returning: demand)
                    self.right = .none
                } else {
                    left = (value, leftContinuation)
                }
            case .terminated:
                demand = try await downstream(.terminated)
                leftContinuation.resume(returning: demand)
                if let right = right {
                    right.1.resume(returning: demand); self.right = .none
                } else if let rightCancellable = rightCancellable {
                    rightCancellable.cancel()
                } else {
                    shouldCancelRight = true
                }
            case let .failure(error):
                demand = try await downstream(.failure(error))
                leftContinuation.resume(returning: demand)
                if let right = right {
                    right.1.resume(returning: demand); self.right = .none
                } else if let rightCancellable = rightCancellable {
                    rightCancellable.cancel()
                } else {
                    shouldCancelRight = true
                }
        }
    }

    mutating func handleRight(
        _ rightResult: AsyncStream<Right>.Result,
        _ rightContinuation: UnsafeContinuation<Demand, Error>
    ) async throws -> Void {
        switch rightResult {
            case let .value(rightValue):
                let (value) = rightValue
                if let left = left {
                    demand = try await downstream(.value((left.0, value)))
                    rightContinuation.resume(returning: demand)
                    left.1.resume(returning: demand)
                    self.left = .none
                } else {
                    right = (value, rightContinuation)
                }
            case .terminated:
                demand = try await downstream(.terminated)
                rightContinuation.resume(returning: demand)
                if let left = left {
                    left.1.resume(returning: demand); self.left = .none
                } else if let leftCancellable = leftCancellable {
                    leftCancellable.cancel()
                } else {
                    shouldCancelLeft = true
                }
            case let .failure(error):
                demand = try await downstream(.failure(error))
                rightContinuation.resume(returning: demand)
                if let left = left {
                    left.1.resume(returning: demand); self.left = .none
                } else if let leftCancellable = leftCancellable {
                    leftCancellable.cancel()
                } else {
                    shouldCancelLeft = true
                }
        }
    }

    mutating func handleSetTasks(
        leftTask: Task<Demand, Swift.Error>,
        rightTask: Task<Demand, Swift.Error>,
        continuation: UnsafeContinuation<Demand, Swift.Error>
    ) async throws -> Void {
        leftCancellable = leftTask
        rightCancellable = rightTask
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

    static func channel(
        onStartup: UnsafeContinuation<Void, Never>,
        _ downstream: @escaping (AsyncStream<(Left, Right)>.Result) async throws -> Demand
    ) -> StatefulChannel<ZipState<Left, Right>, ZipAction<Left, Right>> {
        .init(
            initialState: .init(downstream: downstream, demand: .more),
            eventHandler: .init(buffering: .bufferingOldest(2), onStartup: onStartup),
            operation: Self.reduce
        )
    }
}

public func zip<Left, Right>(
    onCancel: @Sendable @escaping () -> Void = { },
    _ left: Publisher<Left>,
    _ right: Publisher<Right>
) -> Publisher<(Left, Right)> {
    return .init { continuation, downstream in
        .init {
            var zipChannel: StatefulChannel<ZipState<Left, Right>, ZipAction<Left, Right>>!
            await withUnsafeContinuation { zContinuation in
                zipChannel = ZipState<Left, Right>.channel(onStartup: zContinuation, downstream)
            }

            var leftTask: Task<Demand, Swift.Error>!
            await withUnsafeContinuation { lContinuation in
                leftTask = left(onStartup: lContinuation) { leftResult in
                    try await withUnsafeThrowingContinuation { leftContinuation in
                        guard case .enqueued = zipChannel.yield(.setLeft(leftResult, leftContinuation)) else {
                            leftContinuation.resume(throwing: ZipError.internalError)
                            return
                        }
                    }
                }
            }

            var rightTask: Task<Demand, Swift.Error>!
            await withUnsafeContinuation { rContinuation in
                rightTask = right(onStartup: rContinuation) { rightResult in
                    try await withUnsafeThrowingContinuation { rightContinuation in
                        guard case .enqueued = zipChannel.yield(.setRight(rightResult, rightContinuation)) else {
                            rightContinuation.resume(throwing: ZipError.internalError)
                            return
                        }
                    }
                }
            }

            let t1: Task<ZipState<Left, Right>, Swift.Error> = zipChannel.task
            let t2: Task<Demand, Swift.Error> = leftTask
            let t3: Task<Demand, Swift.Error> = rightTask
            let cancellation: @Sendable () -> Void = {
                t1.cancel()
                t2.cancel()
                t3.cancel()
                onCancel()
            }

            return try await withTaskCancellationHandler(handler: cancellation) {
                continuation?.resume()

                let _: Demand = try await withUnsafeThrowingContinuation { dContinuation in
                    guard case .enqueued = zipChannel.yield(
                        .setTasks(left: leftTask, right: rightTask, dContinuation)
                    ) else {
                        cancellation()
                        dContinuation.resume(throwing: ZipError.internalError)
                        return
                    }
                }

                guard !Task.isCancelled else { throw Publisher<(Left, Right)>.Error.cancelled }
                return try await zipChannel.task.value.demand
            }
        }
    }
}
