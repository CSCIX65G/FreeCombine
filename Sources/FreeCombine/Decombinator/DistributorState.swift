//
//  DistributorState.swift
//  
//
//  Created by Van Simmons on 5/10/22.
//
public struct DistributorState<Output: Sendable> {
    let channel: Channel<DistributorState<Output>.Action>
    public private(set) var currentValue: Output?
    var nextKey: Int
    var repeaters: [Int: StateTask<RepeaterState<Int, Output>, RepeaterState<Int, Output>.Action>]

    public enum Action: Sendable {
        case receive(AsyncStream<Output>.Result, UnsafeContinuation<Void, Never>?)
        case subscribe(
            @Sendable (AsyncStream<Output>.Result) async throws -> Demand,
            UnsafeContinuation<Void, Never>?,
            UnsafeContinuation<Cancellable<Demand>, Swift.Error>?
        )
        case unsubscribe(Int)
    }

    public init(channel: Channel<DistributorState<Output>.Action>) {
        self.init(channel: channel, currentValue: .none, nextKey: 0, downstreams: [:])
    }

    public init(
        channel: Channel<DistributorState<Output>.Action>,
        currentValue: Output?,
        nextKey: Int,
        downstreams: [Int: StateTask<RepeaterState<Int, Output>, RepeaterState<Int, Output>.Action>]
    ) {
        self.channel = channel
        self.currentValue = currentValue
        self.nextKey = nextKey
        self.repeaters = downstreams
    }


    static func reduce(`self`: inout Self, action: Self.Action) async throws -> Reducer<Self, Action>.Effect {
        try await `self`.reduce(action: action)
    }

    mutating func reduce(action: Action) async throws -> Reducer<Self, Action>.Effect {
        switch action {
            case let .receive(result, continuation):
                if case let .value(newValue) = result, currentValue != nil { currentValue = newValue }
                await process(currentRepeaters: repeaters, with: result)
                continuation?.resume()
            case let .subscribe(downstream, outerContinuation, continuation):
                do {
                    let channel = self.channel
                    let repeater = try await process(subscription: downstream, continuation: outerContinuation)
                    let key = nextKey
                    continuation?.resume(returning: .init { try await withTaskCancellationHandler(handler: {
                        let queueStatus = channel.yield(.unsubscribe(key))
                        if case .dropped = queueStatus {
                            fatalError("Unable to remove subscriber for subject due to: \(queueStatus)")
                        }
                    }) {
                        try await repeater.finalState.mostRecentDemand
                    } } )
                } catch {
                    continuation?.resume(throwing: error)
                }
            case let .unsubscribe(channelId):
                guard let downstream = repeaters.removeValue(forKey: channelId) else {
                    return .none
                }
                await process(currentRepeaters: [channelId: downstream], with: .completion(.finished))
        }
        return .none
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
                let queueStatus = downstreamTask.send(.repeat(result, semaphore))
                guard case .enqueued = queueStatus else {
                    fatalError("Could not enqueue in Subject reducer while processing key: \(key), status = \(queueStatus)")
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
        let repeaterState = await RepeaterState(id: nextKey, downstream: downstream)
        let repeater: StateTask<RepeaterState<Int, Output>, RepeaterState<Int, Output>.Action> = .init(
            channel: .init(buffering: .bufferingOldest(1)),
            initialState: { _ in repeaterState },
            onStartup: continuation,
            reducer: Reducer(reducer: RepeaterState.reduce)
        )
        if let currentValue = currentValue, try await downstream(.value(currentValue)) == .done {
            return repeater
        }
        repeaters[nextKey] = repeater
        return repeater
    }
}
