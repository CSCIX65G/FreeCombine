//
//  Multicast.swift
//  
//
//  Created by Van Simmons on 6/4/22.
//
public final class Multicaster<Output: Sendable> {
    private let stateTask: StateTask<MulticasterState<Output>, MulticasterState<Output>.Action>
    init(stateTask: StateTask<MulticasterState<Output>, MulticasterState<Output>.Action>) async {
        self.stateTask = stateTask
    }
    public var value: MulticasterState<Output> {
        get async throws { try await stateTask.value }
    }
    public func cancelAndAwaitResult() async throws -> Result<MulticasterState<Output>, Swift.Error> {
        stateTask.cancel()
        return await stateTask.result
    }
}

public extension Multicaster {
    func publisher() -> Publisher<Output> {
        .init(stateTask: stateTask)
    }

    func connect() async throws -> Void {
        let _: Void = try await withResumption { continuation in
            let queueStatus = stateTask.send(.connect(continuation))
            switch queueStatus {
                case .enqueued:
                    ()
                case .terminated:
                    continuation.resume(throwing: PublisherError.completed)
                case .dropped:
                    continuation.resume(throwing: PublisherError.enqueueError)
                @unknown default:
                    continuation.resume(throwing: PublisherError.enqueueError)
            }
        }
    }

    func disconnect() async throws -> Void {
        return try await withResumption({ continuation in
            let queueStatus = stateTask.send(.disconnect(continuation))
            guard case .enqueued = queueStatus else {
                continuation.resume(throwing: PublisherError.enqueueError)
                return
            }
        })
    }

    func pause() async throws -> Void {
        return try await withResumption({ continuation in
            let queueStatus = stateTask.send(.pause(continuation))
            guard case .enqueued = queueStatus else {
                continuation.resume(throwing: PublisherError.enqueueError)
                return
            }
        })
    }

    func resume() async throws -> Void {
        return try await withResumption({ continuation in
            let queueStatus = stateTask.send(.resume(continuation))
            guard case .enqueued = queueStatus else {
                continuation.resume(throwing: PublisherError.enqueueError)
                return
            }
        })
    }
}

public extension Publisher {
    func multicast() async -> Multicaster<Output> {
        try! await .init(
            stateTask: Channel().stateTask(
                initialState: MulticasterState<Output>.create(upstream: self),
                reducer: Reducer(
                    onCompletion: MulticasterState<Output>.complete,
                    disposer: MulticasterState<Output>.dispose,
                    reducer: MulticasterState<Output>.reduce
                )
            )
        )
    }
}
