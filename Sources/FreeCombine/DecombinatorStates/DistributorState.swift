//
//  File.swift
//  
//
//  Created by Van Simmons on 5/10/22.
//
struct DistributorState<Output: Sendable> {
    var currentValue: Output
    var nextKey: Int
    var downstreams: [Int: StateTask<RepeaterState<Int, Output>, RepeaterState<Int, Output>.Action>]

    enum Action: Sendable {
        case receive(AsyncStream<Output>.Result, UnsafeContinuation<Void, Swift.Error>?)
        case subscribe(
            @Sendable (AsyncStream<Output>.Result) async throws -> Demand,
            UnsafeContinuation<Task<Demand, Swift.Error>, Swift.Error>?
        )
        case unsubscribe(Int, UnsafeContinuation<Void, Swift.Error>?)
    }

    mutating func reduce(action: Action) async throws -> Void {
        switch action {
            case let .receive(result, continuation):
                await process(repeaters: downstreams, with: result)
                continuation?.resume()
            case let .subscribe(downstream, continuation):
                let task = await process(subscription: downstream)
                continuation?.resume(returning: task)
            case let .unsubscribe(channelId, continuation):
                guard let downstream = downstreams.removeValue(forKey: channelId) else {
                    fatalError("could not remove requested value")
                }
                await process(repeaters: [channelId: downstream], with: .completion(.finished))
                continuation?.resume()
        }
    }

    mutating func process(
        repeaters : [Int: StateTask<RepeaterState<Int, Output>, RepeaterState<Int, Output>.Action>],
        with result: AsyncStream<Output>.Result
    ) async -> Void {
        await withUnsafeContinuation { (completedContinuation: UnsafeContinuation<[Int], Never>) in
            let semaphore = Semaphore<[Int], RepeaterAction<Int>>(
                continuation: completedContinuation,
                reducer: { completedIds, action in
                    guard case let .repeated(id, .done) = action else { return }
                    completedIds.append(id)
                },
                initialState: [Int](),
                count: downstreams.count
            )
            repeaters.forEach { (key, downstreamTask) in
                guard case .enqueued = downstreamTask.send(.repeat(result, semaphore)) else {
                    fatalError("Internal failure in Subject reducer processing key: \(key)")
                }
            }
        }.forEach { key in downstreams.removeValue(forKey: key) }
    }

    mutating func process(
        subscription downstream: @escaping @Sendable (AsyncStream<Output>.Result) async throws -> Demand
    ) async -> Task<Demand, Swift.Error> {
        nextKey += 1
        let repeater:StateTask<RepeaterState<Int, Output>, RepeaterState<Int, Output>.Action> = await .init(
            initialState: .init(id: nextKey, downstream: downstream),
            buffering: .bufferingOldest(1),
            reducer: RepeaterState.reduce
        )
        downstreams[nextKey] = repeater
        return Task { try await withTaskCancellationHandler(handler: repeater.cancel)  {
            try await repeater.finalState.mostRecentDemand
        } }
    }
}
