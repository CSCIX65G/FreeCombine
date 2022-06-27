//
//  MakeConnectable.swift
//  
//
//  Created by Van Simmons on 6/4/22.
//
public extension Publisher {
    typealias ConnectableTask = StateTask<LazyValueRefState<Connectable<Output>>, LazyValueRefState<Connectable<Output>>.Action>
}

public final class Connectable<Output: Sendable> {
    private let stateTask: StateTask<ConnectableState<Output>, ConnectableState<Output>.Action>
    init(stateTask: StateTask<ConnectableState<Output>, ConnectableState<Output>.Action>) async {
        self.stateTask = stateTask
    }
    public var value: ConnectableState<Output> {
        get async throws { try await stateTask.value }
    }
    public var result: Result<ConnectableState<Output>, Swift.Error> {
        get async { await stateTask.result }
    }
    public func cancelAndAwaitResult() async throws -> Result<ConnectableState<Output>, Swift.Error> {
        stateTask.cancel()
        return await stateTask.result
    }
    public func finish() async -> Void {
        stateTask.finish()
        _ = await stateTask.result
    }
}

public extension Connectable {
    func publisher(
        file: StaticString = #file,
        line: UInt = #line,
        deinitBehavior: DeinitBehavior = .assert
    ) -> Publisher<Output> {
        .init(file: file, line: line, deinitBehavior: deinitBehavior, stateTask: stateTask)
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
    func makeConnectable() async -> Connectable<Output> {
        try! await .init(
            stateTask: Channel().stateTask(
                initialState: ConnectableState<Output>.create(upstream: self),
                reducer: Reducer(
                    onCompletion: ConnectableState<Output>.complete,
                    disposer: ConnectableState<Output>.dispose,
                    reducer: ConnectableState<Output>.reduce
                )
            )
        )
    }
}
