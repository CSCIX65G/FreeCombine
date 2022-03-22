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
    case setLeftCancellable(Task<Demand, Swift.Error>)
    case setRight(AsyncStream<Right>.Result, UnsafeContinuation<Demand, Swift.Error>)
    case setRightCancellable(Task<Demand, Swift.Error>)
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
}

fileprivate func zipReducer<Left, Right>(
    state: inout ZipState<Left, Right>,
    action: ZipAction<Left, Right>,
    service: Service<ZipAction<Left, Right>>
) async throws -> Void {
    switch action {
        case let .setLeft(leftResult, leftContinuation):
            if state.demand == .done {
                leftContinuation.resume(returning: state.demand)
                return
            }
            switch leftResult {
                case let .value(value):
                    if let right = state.right {
                        state.demand = try await state.downstream(.value((value, right.0)))
                        leftContinuation.resume(returning: state.demand)
                        right.1.resume(returning: state.demand)
                        state.right = .none
                    } else {
                        state.left = (value, leftContinuation)
                    }
                    return
                case .terminated:
                    state.demand = try await state.downstream(.terminated)
                    leftContinuation.resume(returning: state.demand)
                    if let right = state.right {
                        right.1.resume(returning: state.demand)
                        state.right = .none
                        service.finish()
                    } else if let rightCancellable = state.rightCancellable {
                        rightCancellable.cancel()
                        service.finish()
                    } else {
                        state.shouldCancelRight = true
                    }
                    return
                case let .failure(error):
                    state.demand = try await state.downstream(.failure(error))
                    leftContinuation.resume(returning: state.demand)
                    if let right = state.right {
                        right.1.resume(returning: state.demand)
                        state.right = .none
                        service.finish()
                    } else if let rightCancellable = state.rightCancellable {
                        rightCancellable.cancel()
                        service.finish()
                    } else {
                        state.shouldCancelRight = true
                    }
                    return
            }
        case let .setRight(rightResult, rightContinuation):
            if state.demand == .done {
                rightContinuation.resume(returning: state.demand)
                return
            }
            switch rightResult {
                case let .value(value):
                    if let left = state.left {
                        state.demand = try await state.downstream(.value((left.0, value)))
                        rightContinuation.resume(returning: state.demand)
                        left.1.resume(returning: state.demand)
                        state.left = .none
                    } else {
                        state.right = (value, rightContinuation)
                    }
                    return
                case .terminated:
                    state.demand = try await state.downstream(.terminated)
                    rightContinuation.resume(returning: state.demand)
                    if let left = state.left {
                        left.1.resume(returning: state.demand)
                        state.left = .none
                        service.finish()
                    } else if let leftCancellable = state.leftCancellable {
                        leftCancellable.cancel()
                        service.finish()
                    } else {
                        state.shouldCancelLeft = true
                    }
                    return
                case let .failure(error):
                    state.demand = try await state.downstream(.failure(error))
                    rightContinuation.resume(returning: state.demand)
                    if let left = state.left {
                        left.1.resume(returning: state.demand)
                        state.left = .none
                        service.finish()
                    } else if let leftCancellable = state.leftCancellable {
                        leftCancellable.cancel()
                        service.finish()
                    } else {
                        state.shouldCancelLeft = true
                    }
                    return
            }
        case let .setLeftCancellable(leftTask):
            guard !state.shouldCancelLeft else {
                leftTask.cancel()
                service.finish()
                return
            }
            state.leftCancellable = leftTask
        case let .setRightCancellable(rightTask):
            guard !state.shouldCancelRight else {
                rightTask.cancel()
                service.finish()
                return
            }
            state.rightCancellable = rightTask
    }
}

fileprivate typealias Zipper<A, B> = AsyncReducer<ZipState<A, B>, ZipAction<A, B>>

fileprivate func zipper<A, B>(
    onStartup: UnsafeContinuation<Void, Never>,
    _ downstream: @escaping (AsyncStream<(A, B)>.Result) async throws -> Demand
) -> Zipper<A, B> {
    .init(
        buffering: .unbounded,
        initialState: .init(
            downstream: downstream,
            demand: .more
        ),
        onStartup: onStartup,
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
            var leftTask: Task<Demand, Swift.Error>!
            var rightTask: Task<Demand, Swift.Error>!

            _ = await withUnsafeContinuation { continuation in
                zipService = zipper(onStartup: continuation, downstream)
            }
            await cancellation.add(zipService.task)

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
            await cancellation.add(leftTask)
            guard case .enqueued = zipService.yield(.setLeftCancellable(leftTask)) else {
                leftTask.cancel()
                zipService.cancel()
                throw ZipError.internalError
            }

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
            await cancellation.add(rightTask)
            guard case .enqueued = zipService.yield(.setRightCancellable(rightTask)) else {
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
