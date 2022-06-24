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
    var isComplete = false

    public enum Error: Swift.Error {
        case alreadyCompleted
    }

    public enum Action: Sendable {
        case receive(AsyncStream<Output>.Result, Resumption<Void>?)
        case subscribe(
            @Sendable (AsyncStream<Output>.Result) async throws -> Demand,
            Resumption<Cancellable<Demand>>
        )
        case unsubscribe(Int)
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

    static func complete(state: inout Self, completion: Reducer<Self, Self.Action>.Completion) async -> Void {
        switch completion {
            case .finished, .exit:
                try! await state.process(currentRepeaters: state.repeaters, with: .completion(.finished))
            case let .failure(error):
                try! await state.process(currentRepeaters: state.repeaters, with: .completion(.failure(error)))
            case .cancel:
                try! await state.process(currentRepeaters: state.repeaters, with: .completion(.cancelled))
        }
        for (_, repeater) in state.repeaters {
            repeater.finish()
        }
        state.repeaters.removeAll()
    }

    static func dispose(action: Self.Action, completion: Reducer<Self, Self.Action>.Completion) async -> Void {
        switch action {
            case let .receive(_, continuation):
                continuation?.resume()
            case let .subscribe(downstream, continuation):
                switch completion {
                    case .failure(PublisherError.completed):
                        let _ = try? await downstream(.completion(.finished))
                        continuation.resume(returning: .init { throw PublisherError.cancelled })
                    case .failure(PublisherError.cancelled):
                        let _ = try? await downstream(.completion(.cancelled))
                        continuation.resume(throwing: PublisherError.cancelled)
                    case let .failure(error):
                        let _ = try? await downstream(.completion(.failure(error)))
                        continuation.resume(throwing: error)
                    default:
                        let _ = try? await downstream(.completion(.finished))
                        continuation.resume(returning: .init { return .done })
                }
            case .unsubscribe:
                ()
        }
    }

    static func reduce(`self`: inout Self, action: Self.Action) async throws -> Reducer<Self, Action>.Effect {
        if Task.isCancelled {
            switch action {
                case .receive(_, let resumption):
                    resumption?.resume(throwing: PublisherError.cancelled)
                case .subscribe(_, let resumption):
                    resumption.resume(throwing: PublisherError.cancelled)
                case .unsubscribe(_):
                    ()
            }
            return .completion(.cancel)
        }
        return try await `self`.reduce(action: action)
    }

    mutating func reduce(action: Action) async throws -> Reducer<Self, Action>.Effect {
        switch action {
            case let .receive(result, resumption):
                if case let .value(newValue) = result, currentValue != nil { currentValue = newValue }
                if case .completion = result { isComplete = true }
                do {
                    try await process(currentRepeaters: repeaters, with: result)
                    resumption?.resume()
                } catch {
                    resumption?.resume()
                    throw error
                }
                return isComplete
                    ? .completion(.exit)
                    : .none
            case let .subscribe(downstream, resumption):
                var repeater: Cancellable<Demand>!
                if isComplete {
                    resumption.resume(returning: .init { try await downstream(.completion(.finished)) } )
                    return .completion(.exit)
                }
                let _: Void = try await withResumption { outerResumption in
                    repeater = process(subscription: downstream, resumption: outerResumption)
                }
                if let currentValue = currentValue, try await downstream(.value(currentValue)) == .done {
                    // FIXME: handle first value cancellation
                }
                resumption.resume(returning: repeater)
                return .none
            case let .unsubscribe(channelId):
                guard let downstream = repeaters.removeValue(forKey: channelId) else {
                    return .none
                }
                try await process(currentRepeaters: [channelId: downstream], with: .completion(.finished))
                return .none
        }
    }

    mutating func process(
        currentRepeaters : [Int: StateTask<RepeaterState<Int, Output>, RepeaterState<Int, Output>.Action>],
        with result: AsyncStream<Output>.Result
    ) async throws -> Void {
        guard currentRepeaters.count > 0 else {
            return
        }
        try await withResumption { (completedResumption: Resumption<[Int]>) in
            // Note that the semaphore's reducer constructs a list of repeaters
            // which have responded with .done and that the elements of that list
            // are removed at completion of the sends
            let semaphore = Semaphore<[Int], RepeatedAction<Int>>(
                resumption: completedResumption,
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
        resumption: Resumption<Void>
    ) -> Cancellable<Demand> {
        nextKey += 1
        let repeaterState = RepeaterState(id: nextKey, downstream: downstream)
        let repeater: StateTask<RepeaterState<Int, Output>, RepeaterState<Int, Output>.Action> = .init(
            channel: .init(buffering: .bufferingOldest(1)),
            initialState: { _ in repeaterState },
            onStartup: resumption,
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
