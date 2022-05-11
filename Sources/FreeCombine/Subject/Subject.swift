//
//  Subject.swift
//  
//
//  Created by Van Simmons on 3/22/22.
//

public final class Subject<Output: Sendable> {
    enum SemaphoreAction {
        case more
        case done(Int)
    }

    struct State {
        var currentValue: Output
        var nextKey: Int
        var downstreams: [Int: StateTask<RepeaterState<Int, Output>, RepeaterState<Int, Output>.Action>]

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
    }

    enum Action: Sendable {
        case receive(AsyncStream<Output>.Result, UnsafeContinuation<Void, Swift.Error>?)
        case subscribe(
            @Sendable (AsyncStream<Output>.Result) async throws -> Demand,
            UnsafeContinuation<Task<Demand, Swift.Error>, Swift.Error>?
        )
        case unsubscribe(Int, UnsafeContinuation<Void, Swift.Error>?)
    }
    private let stateTask: StateTask<Subject<Output>.State, Subject<Output>.Action>

    init(
        currentValue: Output,
        buffering: AsyncStream<Subject<Output>.Action>.Continuation.BufferingPolicy = .bufferingOldest(1),
        onStartup: UnsafeContinuation<Void, Never>? = .none,
        onCancel: @escaping () -> Void = { },
        onCompletion: @escaping (Subject<Output>.State, StateTask<Subject<Output>.State, Subject<Output>.Action>.Completion) -> Void = { _, _ in }
    ) {
        self.stateTask = .init(
            initialState: { channel in .init(currentValue: currentValue, nextKey: 0, downstreams: [:]) },
            buffering: buffering,
            onStartup: onStartup,
            onCancel: onCancel,
            onCompletion: onCompletion,
            reducer: Self.reduce
        )
    }

    static func reduce(`self`: inout State, action: Action) async throws -> Void {
        try await `self`.reduce(action: action)
    }
}
