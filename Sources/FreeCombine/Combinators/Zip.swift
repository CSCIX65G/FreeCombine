//
//  Zip.swift
//  
//
//  Created by Van Simmons on 3/16/22.
//

fileprivate enum Either<A, B> {
    case left(A)
    case right(B)
}

fileprivate enum ZipError: Error {
    case internalError
}

fileprivate struct ZipperState<A, B> {
    var a: AsyncStream<A>.Result?
    var aContinuation: UnsafeContinuation<Demand, Swift.Error>?
    var b: AsyncStream<B>.Result?
    var bContinuation: UnsafeContinuation<Demand, Swift.Error>?
    var demand: Demand

    init(
        a: AsyncStream<A>.Result? = .none,
        aContinuation: UnsafeContinuation<Demand, Swift.Error>? = .none,
        b: AsyncStream<B>.Result? = .none,
        bContinuation: UnsafeContinuation<Demand, Swift.Error>? = .none,
        demand: Demand = .more
    ) {
        self.a = a
        self.aContinuation = aContinuation
        self.b = b
        self.bContinuation = bContinuation
        self.demand = demand
    }

    init(
        other: ZipperState<A, B>,
        a: AsyncStream<A>.Result? = .none,
        aContinuation: UnsafeContinuation<Demand, Swift.Error>? = .none,
        b: AsyncStream<B>.Result? = .none,
        bContinuation: UnsafeContinuation<Demand, Swift.Error>? = .none,
        demand: Demand? = .none
    ) {
        self.a = a ?? other.a
        self.aContinuation = aContinuation ?? other.aContinuation
        self.b = b ?? other.b
        self.bContinuation = bContinuation ?? other.bContinuation
        self.demand = demand ?? other.demand
    }

}

fileprivate typealias Zipper<A, B> = AsyncReducer<
    Either<
        (AsyncStream<A>.Result, UnsafeContinuation<Demand, Swift.Error>),
        (AsyncStream<B>.Result, UnsafeContinuation<Demand, Swift.Error>)
    >, ZipperState<A, B>
>

fileprivate func zipper<A, B>(
    onStartup: UnsafeContinuation<Void, Never>,
    leftCancel: CancellationGroup,
    rightCancel: CancellationGroup,
    _ downstream: @escaping (AsyncStream<(A, B)>.Result) async throws -> Demand
) -> Zipper<A, B> {
    .init(
        buffering: .unbounded,
        initialState: .init(),
        onStartup: onStartup,
        operation: { state, leftOrRight  in
            var newState = state ?? .init()
            switch leftOrRight {
                case let .left((value, continuation)): ()
                    newState = .init(other: newState, a: value, aContinuation: continuation)
                case let .right((value, continuation)): ()
                    newState = .init(other: newState, b: value, bContinuation: continuation)
            }
            switch (newState.a, newState.b) {
                    // Values available
                case let (.value(a), .value(b)):
                    newState.demand = try await downstream(.value((a,b)))
                    newState.aContinuation?.resume(returning: newState.demand)
                    newState.bContinuation?.resume(returning: newState.demand)
                    newState = .init(demand: newState.demand)

                    // Left Terminated
                case (.terminated, _):
                    newState.demand = try await downstream(.terminated)
                    newState.aContinuation?.resume(returning: newState.demand)
                    guard let bc = newState.bContinuation else {
                        try await rightCancel.cancel()
                        break
                    }
                    bc.resume(returning: newState.demand)
                case let (.failure(error), _):
                    newState.demand = try await downstream(.failure(error))
                    newState.aContinuation?.resume(returning: newState.demand)
                    guard let bc = newState.bContinuation else {
                        try await rightCancel.cancel()
                        break
                    }
                    bc.resume(returning: newState.demand)

                // Right Terminated
                case (_, .terminated):
                    newState.demand = try await downstream(.terminated)
                    newState.bContinuation?.resume(returning: newState.demand)
                    guard let ac = newState.aContinuation else {
                        try await leftCancel.cancel()
                        break
                    }
                    ac.resume(returning: newState.demand)
                case let (_, .failure(error)):
                    newState.demand = try await downstream(.failure(error))
                    newState.bContinuation?.resume(returning: newState.demand)
                    guard let ac = newState.aContinuation else {
                        try await leftCancel.cancel()
                        break
                    }
                    ac.resume(returning: newState.demand)

                    // Do nothing
                default:
                    ()
            }
            return newState
        },
        exit: {_, state in state.demand == .done }
    )
}


public func zip<A, B>(
    onCancel: @Sendable @escaping () -> Void,
    _ left: Publisher<A>,
    _ right: Publisher<B>
) -> Publisher<(A, B)> {
    let cancellation = CancellationGroup(onCancel: onCancel)
    return .init { continuation, downstream in
        Task { try await withTaskCancellationHandler(handler: cancellation.nonIsolatedCancel) {
            var leftTask: Task<Demand, Swift.Error>!
            var rightTask: Task<Demand, Swift.Error>!
            let leftCancellable = CancellationGroup()
            await leftCancellable.add(leftTask)
            let rightCancellable = CancellationGroup()
            await rightCancellable.add(rightTask)

            var zipService: Zipper<A, B>! = .none

            _ = await withUnsafeContinuation { continuation in
                zipService = zipper(
                    onStartup: continuation,
                    leftCancel: leftCancellable,
                    rightCancel: rightCancellable,
                    downstream
                )
            }

            _ = await withUnsafeContinuation { continuation in
                leftTask = left(onStartup: continuation) { leftResult in
                    try await withUnsafeThrowingContinuation { leftContinuation in
                        guard case .enqueued = zipService.yield(.left((leftResult, leftContinuation))) else {
                            leftContinuation.resume(throwing: ZipError.internalError)
                            return
                        }
                    }
                }
            }

            _ = await withUnsafeContinuation { continuation in
                rightTask = right(onStartup: continuation) { rightResult in
                    try await withUnsafeThrowingContinuation { rightContinuation in
                        guard case .enqueued = zipService.yield(.right((rightResult, rightContinuation))) else {
                            rightContinuation.resume(throwing: ZipError.internalError)
                            return
                        }
                    }
                }
            }

            continuation?.resume()

            let leftResult = try await leftTask.value
            let rightResult = try await rightTask.value

            switch (leftResult, rightResult) {
                case (.done, .done): return .done
                default: return .more
            }
        } }
    }
}

//public func zip<A, B>(
//    onCancel: @escaping () -> Void = { },
//    _ left: Publisher<A>,
//    _ right: Publisher<B>
//) async -> Publisher<(A, B)> {
//}
