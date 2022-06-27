//
//  Share.swift
//  
//
//  Created by Van Simmons on 6/26/22.
//
public extension Publisher {
    typealias DistributorTask = StateTask<LazyValueRefState<Distributor<Output>>, LazyValueRefState<Distributor<Output>>.Action>
}

public final class Distributor<Output: Sendable> {
    private let stateTask: StateTask<DistributorState<Output>, DistributorState<Output>.Action>
    init(stateTask: StateTask<DistributorState<Output>, DistributorState<Output>.Action>) async {
        self.stateTask = stateTask
    }
    public var value: DistributorState<Output> {
        get async throws { try await stateTask.value }
    }
    public var result: Result<DistributorState<Output>, Swift.Error> {
        get async { await stateTask.result }
    }
    public func cancelAndAwaitResult() async throws -> Result<DistributorState<Output>, Swift.Error> {
        try await stateTask.cancel()
        return await stateTask.result
    }
    public func finish() async throws -> Void {
        try await stateTask.finish()
        _ = await stateTask.result
    }
}

public extension Distributor {
    func publisher(
        file: StaticString = #file,
        line: UInt = #line,
        deinitBehavior: DeinitBehavior = .assert
    ) -> Publisher<Output> {
        .init(file: file, line: line, deinitBehavior: deinitBehavior, stateTask: stateTask)
    }

    func subscribe(
        _ downstream: @Sendable @escaping (AsyncStream<Output>.Result) async throws -> Demand
    ) async throws -> Cancellable<Demand> {
        try await withResumption { resumption in
            let queueStatus = stateTask.send(.subscribe(downstream, resumption))
            switch queueStatus {
                case .enqueued:
                    ()
                case .terminated:
                    resumption.resume(throwing: PublisherError.completed)
                case .dropped:
                    resumption.resume(throwing: PublisherError.enqueueError)
                @unknown default:
                    resumption.resume(throwing: PublisherError.enqueueError)
            }
        }
    }
}

public extension Publisher {
    func share(
        buffering: AsyncStream<DistributorState<Output>.Action>.Continuation.BufferingPolicy = .bufferingOldest(1)
    ) async -> Self {
        let distributorActor: ValueRef<DistributorTask?> = .init(value: .none)
        let distributor = await LazyValueRef(
            creator: {  await Distributor<Output>.init(
                stateTask: try Channel.init(buffering: buffering)
                    .stateTask(
                        initialState: DistributorState<Output>.create(),
                        reducer: Reducer(
                            onCompletion: DistributorState<Output>.complete,
                            disposer: DistributorState<Output>.dispose,
                            reducer: DistributorState<Output>.reduce
                        )
                    )
            ) },
            disposer: { value in
                _ = await distributorActor.value?.finishAndAwaitResult()
            }
        )
        await distributorActor.set(value: distributor)
        return .init { continuation, downstream in
            Cancellable<Cancellable<Demand>>.join(.init {
                @Sendable func lift(
                    _ downstream: @Sendable @escaping (AsyncStream<Output>.Result) async throws -> Demand
                ) -> @Sendable (AsyncStream<Output>.Result) async throws -> Demand {
                    { r in
                        switch r {
                            case .value:
                                return try await downstream(r)
                            case .completion:
                                let finalValue = try await downstream(r)
                                try await distributor.release()
                                return finalValue
                        }
                    }
                }
                do {
                    guard let m = try await distributor.value() else {
                        _ = try? await downstream(.completion(.finished))
                        distributor.cancel()
                        continuation.resume()
                        return Cancellable<Demand> { .done }
                    }
                    let cancellable = try await m.subscribe(lift(downstream))
                    if cancellable.isCancelled {
                        fatalError("Should not be cancelled")
                    }
                    continuation.resume()
                    return cancellable
                } catch {
                    continuation.resume()
                    return .init { try await downstream(.completion(.finished)) }
                }
            } )
        }
    }
}

