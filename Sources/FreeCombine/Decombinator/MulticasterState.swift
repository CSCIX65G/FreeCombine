//
//  MulticasterState.swift
//  
//
//  Created by Van Simmons on 6/5/22.
//

public struct MulticasterState<Output: Sendable> {
    public enum Action: Sendable {
        case connect(UnsafeContinuation<Void, Swift.Error>)
        case pause(UnsafeContinuation<Void, Swift.Error>)
        case resume(UnsafeContinuation<Void, Swift.Error>)
        case disconnect(UnsafeContinuation<Void, Swift.Error>)
        
        case receive(AsyncStream<Output>.Result, UnsafeContinuation<Demand, Swift.Error>)
        case subscribe(
            @Sendable (AsyncStream<Output>.Result) async throws -> Demand,
            UnsafeContinuation<Cancellable<Demand>, Swift.Error>
        )
        case unsubscribe(Int)
    }

    public enum Error: Swift.Error {
        case alreadyConnected
        case alreadyDisconnected
        case disconnected
        case alreadyPaused
        case alreadyResumed
        case internalError
    }

    let upstream: Publisher<Output>
    let downstream: @Sendable (AsyncStream<Output>.Result) async throws -> Demand

    var cancellable: Cancellable<Demand>?
    var nextKey: Int
    var repeaters: [Int: StateTask<RepeaterState<Int, Output>, RepeaterState<Int, Output>.Action>]
    var upstreamContinuation: UnsafeContinuation<Demand, Swift.Error>?
    var isRunning: Bool = false

    public init(
        upstream: Publisher<Output>,
        channel: Channel<MulticasterState<Output>.Action>
    ) {
        self.upstream = upstream
        self.nextKey = 0
        self.repeaters = [:]
        self.downstream = { r in try await withUnsafeThrowingContinuation { continuation in
            channel.yield(.receive(r, continuation))
        } }
    }

    static func create(
        upstream: Publisher<Output>
    ) -> (Channel<MulticasterState<Output>.Action>) -> Self {
        { channel in .init(upstream: upstream, channel: channel) }
    }

    static func complete(state: inout Self, completion: Reducer<Self, Self.Action>.Completion) async -> Void {
        switch completion {
            case .termination:
                await state.process(currentRepeaters: state.repeaters, with: .completion(.finished))
            case .exit:
                fatalError("Multicaster should never exit")
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
            case let .connect(continuation):
                guard case .none = cancellable else {
                    continuation.resume(throwing: Error.alreadyConnected)
                    return .completion(.failure(Error.alreadyConnected))
                }
                cancellable = await upstream.sink(downstream)
                isRunning = true
                continuation.resume()
                return .none
            case let .pause(continuation):
                guard let _ = cancellable else {
                    continuation.resume(throwing: Error.disconnected)
                    return .completion(.failure(Error.disconnected))
                }
                guard isRunning else {
                    continuation.resume(throwing: Error.alreadyPaused)
                    return .completion(.failure(Error.alreadyPaused))
                }
                isRunning = false
                continuation.resume()
                return .none
            case let .resume(continuation):
                guard let _ = cancellable else {
                    continuation.resume(throwing: Error.disconnected)
                    return .completion(.failure(Error.disconnected))
                }
                guard !isRunning else {
                    continuation.resume(throwing: Error.alreadyResumed)
                    return .completion(.failure(Error.alreadyResumed))
                }
                isRunning = true
                upstreamContinuation?.resume(returning: .more)
                continuation.resume()
                return .none
            case let .disconnect(continuation):
                guard let _ = cancellable else {
                    continuation.resume(throwing: Error.alreadyDisconnected)
                    return .completion(.failure(Error.alreadyDisconnected))
                }
                isRunning = false
                upstreamContinuation?.resume(returning: .done)
                continuation.resume()
                return .completion(.exit)
            case let .receive(result, continuation):
                guard case .none = upstreamContinuation else {
                    upstreamContinuation?.resume(throwing: Error.internalError)
                    continuation.resume(throwing: Error.internalError)
                    return .completion(.failure(Error.internalError))
                }
                await process(currentRepeaters: repeaters, with: result)
                if isRunning {
                    continuation.resume(returning: .more)
                    upstreamContinuation = .none
                } else {
                    upstreamContinuation = continuation
                }
                return .none
            case let .subscribe(downstream, continuation):
                var repeater: Cancellable<Demand>!
                let _: Void = await withUnsafeContinuation { outerContinuation in
                    repeater = process(subscription: downstream, continuation: outerContinuation)
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
        return .init(
            cancel: {
                repeater.cancel()
            },
            isCancelled: { repeater.isCancelled },
            value: {
                do {
                    let value = try await repeater.value
                    return value.mostRecentDemand
                } catch {
                    fatalError("Could not get demand.  Error: \(error)")
                }
            },
            result: {
                await repeater.result.map(\.mostRecentDemand)
            }
        )
    }
}
