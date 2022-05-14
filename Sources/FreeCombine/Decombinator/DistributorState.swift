//
//  DistributorState.swift
//  
//
//  Created by Van Simmons on 5/10/22.
//
public struct DistributorState<Output: Sendable> {
    private var channel: Channel<DistributorState<Output>.Action>
    private var currentValue: Output?
    private var nextKey: Int
    private var downstreams: [Int: StateTask<RepeaterState<Int, Output>, RepeaterState<Int, Output>.Action>]

    public enum Action: Sendable {
        case receive(AsyncStream<Output>.Result, UnsafeContinuation<Void, Swift.Error>?)
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

    public init(
        channel: Channel<DistributorState<Output>.Action>
    ) {
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
        self.downstreams = downstreams
    }


    mutating func reduce(action: Action) async throws -> Void {
        switch action {
            case let .receive(result, continuation):
                await process(repeaters: downstreams, with: result)
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
            print("making semaphore")
            let semaphore = Semaphore<[Int], RepeatedAction<Int>>(
                continuation: completedContinuation,
                reducer: { completedIds, action in
                    guard case let .repeated(id, .done) = action else { return }
                    completedIds.append(id)
                },
                initialState: [Int](),
                count: downstreams.count
            )
            print("sending downstream")
            repeaters.forEach { (key, downstreamTask) in
                guard case .enqueued = downstreamTask.send(.repeat(result, semaphore)) else {
                    fatalError("Internal failure in Subject reducer processing key: \(key)")
                }
            }
        }
        .forEach { key in downstreams.removeValue(forKey: key) }
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
        downstreams[nextKey] = repeater
        return repeater
    }
}
