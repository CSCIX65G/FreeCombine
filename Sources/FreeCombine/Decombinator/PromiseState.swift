//
//  PromiseState.swift
//
//
//  Created by Van Simmons on 5/10/22.
//
public struct PromiseState<Output: Sendable> {
    public private(set) var currentValue: Output?
    var nextKey: Int
    var repeaters: [Int: StateTask<PromiseRepeaterState<Int, Output>, PromiseRepeaterState<Int, Output>.Action>]
    var isComplete = false
    public let file: StaticString
    public let line: UInt

    public enum Error: Swift.Error {
        case alreadyCompleted
    }

    public enum Action: Sendable {
        case receive(Result<Output, Swift.Error>, Resumption<Int>)
        case subscribe(
            @Sendable (Result<Output, Swift.Error>) async throws -> Void,
            Resumption<Cancellable<Void>>
        )
        case unsubscribe(Int)
    }

    public init(
        file: StaticString = #file,
        line: UInt = #line,
        currentValue: Output?,
        nextKey: Int,
        downstreams: [Int: StateTask<PromiseRepeaterState<Int, Output>, PromiseRepeaterState<Int, Output>.Action>]
    ) {
        self.file = file
        self.line = line
        self.currentValue = currentValue
        self.nextKey = nextKey
        self.repeaters = downstreams
    }

    static func create(
    ) -> (Channel<PromiseState<Output>.Action>) -> Self {
        { channel in .init(currentValue: .none, nextKey: 0, downstreams: [:]) }
    }

    static func complete(state: inout Self, completion: Reducer<Self, Self.Action>.Completion) async -> Void {
        switch completion {
            case .finished, .exit:
                assert(
                    state.repeaters.count == 0,
                    "ABORTING DUE TO LEAKED \(type(of: state)) CREATED @ \(state.file): \(state.line)"
                )
            case let .failure(error):
                try! await state.process(currentRepeaters: state.repeaters, with: .failure(error))
            case .cancel:
                try! await state.process(
                    currentRepeaters: state.repeaters,
                    with: .failure(PublisherError.cancelled)
                )
        }
        for (_, repeater) in state.repeaters {
            repeater.finish()
        }
        state.repeaters.removeAll()
    }

    static func dispose(action: Self.Action, completion: Reducer<Self, Self.Action>.Completion) async -> Void {
        switch action {
            case let .receive(_, continuation):
                continuation.resume(throwing: PublisherError.cancelled)
            case let .subscribe(downstream, continuation):
                switch completion {
                    case let .failure(error):
                        let _ = try? await downstream(.failure(error))
                        continuation.resume(throwing: error)
                    default:
                        let _ = try? await downstream(.failure(PublisherError.completed))
                        continuation.resume(throwing: PublisherError.cancelled)
                }
            case .unsubscribe:
                ()
        }
    }

    static func reduce(`self`: inout Self, action: Self.Action) async throws -> Reducer<Self, Action>.Effect {
        if Task.isCancelled {
            switch action {
                case .receive(_, let resumption):
                    resumption.resume(throwing: PublisherError.cancelled)
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
                if case let .success(newValue) = result, currentValue != nil { currentValue = newValue }
                if case .success = result { isComplete = true }
                do {
                    let repeaterCount = repeaters.count
                    try await process(currentRepeaters: repeaters, with: result)
                    resumption.resume(returning: repeaterCount)
                } catch {
                    resumption.resume(throwing: error)
                    throw error
                }
                return isComplete
                    ? .completion(.exit)
                    : .none
            case let .subscribe(downstream, resumption):
                var repeater: Cancellable<Void>!
                if let currentValue = currentValue {
                    resumption.resume(returning: .init { try await downstream(.success(currentValue)) } )
                    return .completion(.exit)
                } else if isComplete {
                    resumption.resume(returning: .init { try await downstream(.failure(PublisherError.cancelled)) } )
                    return .completion(.exit)
                }
                let _: Void = try await withResumption { outerResumption in
                    repeater = process(subscription: downstream, resumption: outerResumption)
                }
                resumption.resume(returning: repeater)
                return .none
            case let .unsubscribe(channelId):
                guard let downstream = repeaters.removeValue(forKey: channelId) else {
                    return .none
                }
                try await process(currentRepeaters: [channelId: downstream], with: .failure(PublisherError.cancelled))
                return .none
        }
    }

    mutating func process(
        currentRepeaters : [Int: StateTask<PromiseRepeaterState<Int, Output>, PromiseRepeaterState<Int, Output>.Action>],
        with result: Result<Output, Swift.Error>
    ) async throws -> Void {
        guard currentRepeaters.count > 0 else { return }
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

            currentRepeaters.forEach { key, downstreamTask in
                let queueStatus = downstreamTask.send(.complete(result, semaphore))
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
        subscription downstream: @escaping @Sendable (Result<Output, Swift.Error>) async throws -> Void,
        resumption: Resumption<Void>
    ) -> Cancellable<Void> {
        nextKey += 1
        let repeaterState = PromiseRepeaterState(id: nextKey, downstream: downstream)
        let repeater: StateTask<PromiseRepeaterState<Int, Output>, PromiseRepeaterState<Int, Output>.Action> = .init(
            channel: .init(buffering: .bufferingOldest(1)),
            initialState: { _ in repeaterState },
            onStartup: resumption,
            reducer: Reducer(
                onCompletion: PromiseRepeaterState.complete,
                reducer: PromiseRepeaterState.reduce
            )
        )
        repeaters[nextKey] = repeater
        return .init { try await repeater.value }
    }
}

