//
//  DistributorState.swift
//  
//
//  Created by Van Simmons on 5/10/22.
//
public struct DistributorState<Output: Sendable> {
    public private(set) var currentValue: Output?
//    let channel: Channel<DistributorState<Output>.Action>
    var nextKey: Int
    var repeaters: [Int: StateTask<RepeaterState<Int, Output>, RepeaterState<Int, Output>.Action>]
    var isComplete = false

    public enum Error: Swift.Error {
        case alreadyCompleted
    }

    public enum Action: Sendable, CustomStringConvertible {
        case receive(AsyncStream<Output>.Result, UnsafeContinuation<Void, Never>?)
        case subscribe(
            @Sendable (AsyncStream<Output>.Result) async throws -> Demand,
            UnsafeContinuation<Cancellable<Demand>, Swift.Error>
        )
        case unsubscribe(Int)

        public var description: String {
            switch self {
                case let .receive(result, _): return "receive(\(result)"
                case .subscribe: return "subscribe"
                case let .unsubscribe(key): return "unsubscribe(\(key))"
            }
        }
    }

    public init(
//        channel: Channel<DistributorState<Output>.Action>,
        currentValue: Output?,
        nextKey: Int,
        downstreams: [Int: StateTask<RepeaterState<Int, Output>, RepeaterState<Int, Output>.Action>]
    ) {
//        self.channel = channel
        self.currentValue = currentValue
        self.nextKey = nextKey
        self.repeaters = downstreams
    }

    static func dispose(action: Self.Action, completion: Reducer<Self, Self.Action>.Completion) async -> Void {
        switch action {
            case let .receive(_, continuation): continuation?.resume()
            case let .subscribe(downstream, continuation):
                switch completion {
                    case .failure(PublisherError.completed):
                        let c = Cancellable { try await downstream(.completion(.finished)) }
                        continuation.resume(returning: c)
                    case .failure(PublisherError.cancelled):
                        continuation.resume(
                            returning: .init { return try await downstream(.completion(.cancelled))}
                        )
                    case let .failure(error):
                        continuation.resume(
                            returning: .init { return try await downstream(.completion(.failure(error)))}
                        )
                    default:
                        continuation.resume(
                            returning: .init { return try await downstream(.completion(.finished))}
                        )
                }
            case .unsubscribe: ()
        }
    }

    static func complete(state: inout Self, completion: Reducer<Self, Self.Action>.Completion) async -> Void {
        switch completion {
            case .finished, .exit:
                await state.process(currentRepeaters: state.repeaters, with: .completion(.finished))
            case let .failure(error):
                await state.process(currentRepeaters: state.repeaters, with: .completion(.failure(error)))
            case .cancel:
                await state.process(currentRepeaters: state.repeaters, with: .completion(.cancelled))
        }
        for (_, repeater) in state.repeaters {
            repeater.finish()
        }
        state.repeaters.removeAll()
    }

    static func reduce(`self`: inout Self, action: Self.Action) async throws -> Reducer<Self, Action>.Effect {
        try await `self`.reduce(action: action)
    }

    mutating func reduce(action: Action) async throws -> Reducer<Self, Action>.Effect {
        switch action {
            case let .receive(result, continuation):
                if case let .value(newValue) = result, currentValue != nil { currentValue = newValue }
                if case .completion = result {
                    isComplete = true
                }
                await process(currentRepeaters: repeaters, with: result)
                continuation?.resume()
                return isComplete
                    ? .completion(.exit)
                    : .none
            case let .subscribe(downstream, continuation):
                var repeater: Cancellable<Demand>!
                if isComplete {
                    continuation.resume(returning: .init { try await downstream(.completion(.finished)) } )
                    return .completion(.exit)
                }
                let _: Void = await withUnsafeContinuation { outerContinuation in
                    repeater = process(subscription: downstream, continuation: outerContinuation)
                }
                if let currentValue = currentValue, try await downstream(.value(currentValue)) == .done {
                    // FIXME: handle first value cancellation
                }
                continuation.resume(returning: repeater)
                return .none
            case let .unsubscribe(channelId):
                guard let downstream = repeaters.removeValue(forKey: channelId) else {
                    return .none
                }
                await process(currentRepeaters: [channelId: downstream], with: .completion(.finished))
                return .none
        }
    }

    mutating func process(
        currentRepeaters : [Int: StateTask<RepeaterState<Int, Output>, RepeaterState<Int, Output>.Action>],
        with result: AsyncStream<Output>.Result
    ) async -> Void {
        guard currentRepeaters.count > 0 else {
            return
        }
        await withUnsafeContinuation { (completedContinuation: UnsafeContinuation<[Int], Never>) in
            // Note that the semaphore's reducer constructs a list of repeaters
            // which have responded with .done and that the elements of that list
            // are removed at completion of the sends
            let semaphore = Semaphore<[Int], RepeatedAction<Int>>(
                continuation: completedContinuation,
                reducer: { completedIds, action in
                    guard case let .repeated(id, .done) = action else { return }
                    completedIds.append(id)
                },
                initialState: [Int](),
                count: currentRepeaters.count
            )

            for (key, downstreamTask) in currentRepeaters {
                let queueStatus = downstreamTask.send(.repeat(result, semaphore))
                switch queueStatus {
                    case .enqueued:
                        ()
                    case .terminated:
                        Task { await semaphore.decrement(with: .repeated(key, .done)) }
                    case .dropped:
                        fatalError("Should never drop")
                    @unknown default:
                        fatalError("Handle new case")
                }
            }
        }
        .forEach { key in
            repeaters.removeValue(forKey: key)
        }
    }

    mutating func process(
        subscription downstream: @escaping @Sendable (AsyncStream<Output>.Result) async throws -> Demand,
        continuation: UnsafeContinuation<Void, Never>?
    ) -> Cancellable<Demand> {
        nextKey += 1
        let repeaterState = RepeaterState(id: nextKey, downstream: downstream)
        let repeater: StateTask<RepeaterState<Int, Output>, RepeaterState<Int, Output>.Action> = .init(
            channel: .init(buffering: .bufferingOldest(1)),
            initialState: { _ in repeaterState },
            onStartup: continuation,
            reducer: Reducer(
                onCompletion: RepeaterState.complete,
                reducer: RepeaterState.reduce
            )
        )
        repeaters[nextKey] = repeater
        return .init {
            try await withTaskCancellationHandler(handler: repeater.cancel) {
                try await repeater.value.mostRecentDemand
            }
        }
    }
}
