//
//  DistributorState.swift
//  
//
//  Created by Van Simmons on 5/10/22.
//
public struct DistributorState<Output: Sendable> {
    public private(set) var currentValue: Output?
    var nextKey: Int
    var repeaters: [Int: StateTask<RepeaterState<Int, Output>, RepeaterState<Int, Output>.Action>]

    public enum Action: Sendable {
        case receive(AsyncStream<Output>.Result, UnsafeContinuation<Void, Never>?)
        case subscribe(
            @Sendable (AsyncStream<Output>.Result) async throws -> Demand,
            UnsafeContinuation<Void, Never>?,
            UnsafeContinuation<Task<Demand, Swift.Error>, Swift.Error>?
        )
        case unsubscribe(Int, UnsafeContinuation<Void, Swift.Error>?)
    }

    static func reduce(`self`: inout Self, action: Self.Action) async throws -> Void {
        try await `self`.reduce(action: action)
    }

    public init(channel _: Channel<DistributorState<Output>.Action>) {
        self.init(currentValue: .none, nextKey: 0, downstreams: [:])
    }

    public init(
        currentValue: Output?,
        nextKey: Int,
        downstreams: [Int: StateTask<RepeaterState<Int, Output>, RepeaterState<Int, Output>.Action>]
    ) {
        self.currentValue = currentValue
        self.nextKey = nextKey
        self.repeaters = downstreams
    }


    mutating func reduce(action: Action) async throws -> Void {
        switch action {
            case let .receive(result, continuation):
                if case let .value(newValue) = result, currentValue != nil { currentValue = newValue }
                await process(currentRepeaters: repeaters, with: result)
                continuation?.resume()
            case let .subscribe(downstream, outerContinuation, continuation):
                do {
                    let repeater = try await process(subscription: downstream, continuation: outerContinuation)
                    continuation?.resume(returning: Task { try await withTaskCancellationHandler(handler: repeater.cancel)  {
                        try await repeater.finalState.mostRecentDemand
                    } } )
                } catch {
                    continuation?.resume(throwing: error)
                }
            case let .unsubscribe(channelId, continuation):
                guard let downstream = repeaters.removeValue(forKey: channelId) else {
                    fatalError("could not remove requested value")
                }
                await process(currentRepeaters: [channelId: downstream], with: .completion(.finished))
                continuation?.resume()
        }
    }

    mutating func process(
        currentRepeaters : [Int: StateTask<RepeaterState<Int, Output>, RepeaterState<Int, Output>.Action>],
        with result: AsyncStream<Output>.Result
    ) async -> Void {
        await withUnsafeContinuation { (completedContinuation: UnsafeContinuation<[Int], Never>) in
            let semaphore = Semaphore<[Int], RepeatedAction<Int>>(
                continuation: completedContinuation,
                reducer: { completedIds, action in
                    guard case let .repeated(id, .done) = action else { return }
                    completedIds.append(id)
                },
                initialState: [Int](),
                count: currentRepeaters.count
            )

            currentRepeaters.forEach { (key, downstreamTask) in
                guard case .enqueued = downstreamTask.send(.repeat(result, semaphore)) else {
                    fatalError("Internal failure in Subject reducer processing key: \(key)")
                }
            }
        }
        .forEach { key in repeaters.removeValue(forKey: key) }
    }

    mutating func process(
        subscription downstream: @escaping @Sendable (AsyncStream<Output>.Result) async throws -> Demand,
        continuation: UnsafeContinuation<Void, Never>?
    ) async throws -> StateTask<RepeaterState<Int, Output>, RepeaterState<Int, Output>.Action> {
        nextKey += 1
        let repeater: StateTask<RepeaterState<Int, Output>, RepeaterState<Int, Output>.Action> = await .init(
            initialState: .init(id: nextKey, downstream: downstream),
            buffering: .bufferingOldest(1),
            onStartup: continuation,
            reducer: RepeaterState.reduce
        )
        if let currentValue = currentValue, try await downstream(.value(currentValue)) == .done {
            return repeater
        }
        repeaters[nextKey] = repeater
        return repeater
    }
}
