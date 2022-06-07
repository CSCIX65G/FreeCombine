//
//  Multicast.swift
//  
//
//  Created by Van Simmons on 6/4/22.
//
public struct Multicaster<Output> {
    private let stateTask: StateTask<MulticasterState<Output>, MulticasterState<Output>.Action>
    init(stateTask: StateTask<MulticasterState<Output>, MulticasterState<Output>.Action>) async {
        self.stateTask = stateTask
    }
}

public extension Multicaster {
    func publisher() -> Publisher<Output> {
        .init(stateTask: self.stateTask)
    }

    func connect() async throws -> Void {
        return try await withUnsafeThrowingContinuation({ continuation in
            let queueStatus = stateTask.send(.connect(continuation))
            guard case .enqueued = queueStatus else {
                continuation.resume(throwing: PublisherError.enqueueError)
                return
            }
        })
    }

    func disconnect() async throws -> Void {
        return try await withUnsafeThrowingContinuation({ continuation in
            let queueStatus = stateTask.send(.disconnect(continuation))
            guard case .enqueued = queueStatus else {
                continuation.resume(throwing: PublisherError.enqueueError)
                return
            }
        })
    }

    func pause() async throws -> Void {
        return try await withUnsafeThrowingContinuation({ continuation in
            let queueStatus = stateTask.send(.pause(continuation))
            guard case .enqueued = queueStatus else {
                continuation.resume(throwing: PublisherError.enqueueError)
                return
            }
        })
    }

    func resume() async throws -> Void {
        return try await withUnsafeThrowingContinuation({ continuation in
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
        await .init(
            stateTask: Channel.init().stateTask(
                initialState: MulticasterState<Output>.create(upstream: self),
                reducer: Reducer(
                    onCompletion: MulticasterState<Output>.complete,
                    reducer: MulticasterState<Output>.reduce
                )
            )
        )
    }
}