//
//  Zip.swift
//  
//
//  Created by Van Simmons on 3/16/22.
//

fileprivate enum ZipError: Error {
    case internalError
}

fileprivate enum ZipAction<Left, Right> {
    case setLeft(AsyncStream<Left>.Result, UnsafeContinuation<Demand, Swift.Error>)
    case setRight(AsyncStream<Right>.Result, UnsafeContinuation<Demand, Swift.Error>)
    case setTasks(left: Task<Demand, Swift.Error>, right: Task<Demand, Swift.Error>)
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
                    right.1.resume(returning: demand)
                    self.right = .none
                } else if let rightCancellable = rightCancellable {
                    rightCancellable.cancel()
                } else {
                    shouldCancelRight = true
                }
            case let .failure(error):
                demand = try await downstream(.failure(error))
                leftContinuation.resume(returning: demand)
                if let right = right {
                    right.1.resume(returning: demand)
                    self.right = .none
                } else if let rightCancellable = rightCancellable {
                    rightCancellable.cancel()
                } else {
                    shouldCancelRight = true
                }
        }
    }

    mutating fileprivate func handleRight(
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
                    left.1.resume(returning: demand)
                    self.left = .none
                } else if let leftCancellable = leftCancellable {
                    leftCancellable.cancel()
                } else {
                    shouldCancelLeft = true
                }
            case let .failure(error):
                demand = try await downstream(.failure(error))
                rightContinuation.resume(returning: demand)
                if let left = left {
                    left.1.resume(returning: demand)
                    self.left = .none
                } else if let leftCancellable = leftCancellable {
                    leftCancellable.cancel()
                } else {
                    shouldCancelLeft = true
                }
        }
    }}


fileprivate func zipReducer<Left, Right>(
    state: inout ZipState<Left, Right>,
    action: ZipAction<Left, Right>
) async throws -> Void {
    switch action {
        case let .setLeft(leftResult, leftContinuation):
            if state.demand == .done {
                leftContinuation.resume(returning: state.demand)
                return
            }
            return try await state.handleLeft(leftResult, leftContinuation)
        case let .setRight(rightResult, rightContinuation):
            if state.demand == .done {
                rightContinuation.resume(returning: state.demand)
                return
            }
            return try await state.handleRight(rightResult, rightContinuation)
        case let .setTasks(left: leftTask, right: rightTask):
            state.leftCancellable = leftTask
            state.rightCancellable = rightTask
            return
    }
}

fileprivate typealias Zipper<A, B> = StatefulChannel<ZipState<A, B>, ZipAction<A, B>>

fileprivate func zipper<A, B>(
    onStartup: UnsafeContinuation<Void, Never>,
    _ downstream: @escaping (AsyncStream<(A, B)>.Result) async throws -> Demand
) -> Zipper<A, B> {
    .init(
        initialState: .init(downstream: downstream, demand: .more),
        eventHandler: .init(onStartup: onStartup),
        operation: zipReducer
    )
}

public func zip<A, B>(
    onCancel: @Sendable @escaping () -> Void = { },
    _ left: Publisher<A>,
    _ right: Publisher<B>
) -> Publisher<(A, B)> {
    let cancellation = CancellationGroup(onCancel: onCancel)
    return .init { continuation, downstream in
        .init { try await withTaskCancellationHandler(handler: cancellation.nonIsolatedCancel) {
            var zipService: Zipper<A, B>!
            _ = await withUnsafeContinuation { continuation in
                zipService = zipper(onStartup: continuation, downstream)
            }
            await cancellation.add(zipService.task)

            var leftTask: Task<Demand, Swift.Error>!
            _ = await withUnsafeContinuation { continuation in
                leftTask = left(onStartup: continuation) { leftResult in
                    try await withUnsafeThrowingContinuation { leftContinuation in
                        guard case .enqueued = zipService.yield(.setLeft(leftResult, leftContinuation)) else {
                            leftContinuation.resume(throwing: ZipError.internalError)
                            return
                        }
                    }
                }
            }

            var rightTask: Task<Demand, Swift.Error>!
            _ = await withUnsafeContinuation { continuation in
                rightTask = right(onStartup: continuation) { rightResult in
                    try await withUnsafeThrowingContinuation { rightContinuation in
                        guard case .enqueued = zipService.yield(.setRight(rightResult, rightContinuation)) else {
                            rightContinuation.resume(throwing: ZipError.internalError)
                            return
                        }
                    }
                }
            }
            await cancellation.add(leftTask)
            await cancellation.add(rightTask)
            guard case .enqueued = zipService.yield(.setTasks(left: leftTask, right: rightTask)) else {
                leftTask.cancel()
                rightTask.cancel()
                zipService.cancel()
                throw ZipError.internalError
            }

            guard !Task.isCancelled else {
                leftTask.cancel()
                rightTask.cancel()
                zipService.cancel()
                throw Publisher<(A, B)>.Error.cancelled
            }

            continuation?.resume()
            return try await zipService.task.value.demand
        } }
    }
}
