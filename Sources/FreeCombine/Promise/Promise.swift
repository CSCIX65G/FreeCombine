//
//  Promise.swift
//
//
//  Created by Van Simmons on 6/28/22.
//
import Atomics

public final class Promise<Output: Sendable> {
    fileprivate let resolution: ValueRef<Result<Output, Swift.Error>?> = .init(value: .none)
    private let stateTask: StateTask<PromiseState<Output>, PromiseState<Output>.Action>
    private let receiveStateTask: StateTask<PromiseReceiveState<Output>, PromiseReceiveState<Output>.Action>

    let file: StaticString
    let line: UInt
    let deinitBehavior: DeinitBehavior

    init(
        file: StaticString = #file,
        line: UInt = #line,
        deinitBehavior: DeinitBehavior = .assert,
        buffering: AsyncStream<PromiseReceiveState<Output>.Action>.Continuation.BufferingPolicy = .bufferingOldest(1),
        stateTask: StateTask<PromiseState<Output>, PromiseState<Output>.Action>
    ) async throws {
        self.file = file
        self.line = line
        self.deinitBehavior = deinitBehavior
        self.stateTask = stateTask
        self.receiveStateTask = try await Channel(buffering: buffering).stateTask(
            file: file,
            line: line,
            deinitBehavior: deinitBehavior,
            initialState: PromiseReceiveState<Output>.create(promiseChannel: stateTask.channel),
            reducer: .init(
                onCompletion: PromiseReceiveState<Output>.complete,
                disposer: PromiseReceiveState<Output>.dispose,
                reducer: PromiseReceiveState<Output>.reduce
            )
        )
    }

    convenience init(
        file: StaticString = #file,
        line: UInt = #line,
        deinitBehavior: DeinitBehavior = .assert
    ) async throws {
        try await self.init(
            file: file,
            line: line,
            deinitBehavior: deinitBehavior,
            buffering: .bufferingOldest(1),
            stateTask: Channel.init(buffering: .unbounded) .stateTask(
                initialState: { channel in .init(currentValue: .none, nextKey: 0, downstreams: [:]) },
                reducer: Reducer(
                    onCompletion: PromiseState<Output>.complete,
                    disposer: PromiseState<Output>.dispose,
                    reducer: PromiseState<Output>.reduce
                )
            )
        )
    }

    deinit {
        let shouldCancel = !(isCompleting || isCancelled)
        switch deinitBehavior {
            case .assert:
                assert(!shouldCancel, "ABORTING DUE TO LEAKED \(type(of: Self.self)) CREATED @ \(file): \(line)")
            case .logAndCancel:
                if shouldCancel { print("CANCELLING LEAKED \(type(of: Self.self)) CREATED @ \(file): \(line)") }
            case .silentCancel:
                ()
        }
        if shouldCancel {
            receiveStateTask.cancel()
            stateTask.cancel()
        }
    }

    public var isCancelled: Bool {
        @Sendable get {
            stateTask.isCancelled && receiveStateTask.isCancelled
        }
    }
    public var isCompleting: Bool {
        @Sendable get {
            stateTask.isCompleting && receiveStateTask.isCompleting
        }
    }
    public var value: PromiseState<Output> {
        get async throws {
            _ = await receiveStateTask.result
            return try await stateTask.value
        }
    }
    public var result: Result<PromiseState<Output>, Swift.Error> {
        get async {
            _ = await receiveStateTask.result
            return await stateTask.result
        }
    }
    public func cancel() async throws -> Void {
        receiveStateTask.cancel()
        try await stateTask.cancel()
    }
    public func cancelAndAwaitResult() async throws -> Result<PromiseState<Output>, Swift.Error> {
        receiveStateTask.cancel()
        try await stateTask.cancel()
        return await stateTask.result
    }

    public func failAndAwaitResult(_ error: Error) async throws -> Result<PromiseState<Output>, Swift.Error> {
        try await stateTask.fail(error)
        return await stateTask.result
    }
}

extension Promise {
    func subscribe(
        _ downstream: @escaping @Sendable (Result<Output, Swift.Error>) async throws -> Void
    ) async throws -> Cancellable<Void> {
        try await withResumption { resumption in
            let queueStatus = stateTask.send(.subscribe(downstream, resumption))
            switch queueStatus {
                case .enqueued:
                    ()
                case .terminated:
                    resumption.resume(throwing: PublisherError.completed)
                case .dropped:
                    resumption.resume(throwing: PublisherError.enqueueError)
                @unknown default:
                    resumption.resume(throwing: PublisherError.enqueueError)
            }
        }
    }
}

public extension Promise {
    func future(
        file: StaticString = #file,
        line: UInt = #line,
        deinitBehavior: DeinitBehavior = .assert
    ) -> Future<Output> {
        .init(file: file, line: line, deinitBehavior: deinitBehavior, stateTask: stateTask)
    }

    var future: Future<Output> {
        get {
            .init(file: file, line: line, deinitBehavior: deinitBehavior, stateTask: stateTask)
        }
    }

    func receive(
        _ result: Result<Output, Swift.Error>
    ) async throws -> Void {
        try await resolution.swapIfNone(result)
        let queueStatus = receiveStateTask.send(.nonBlockingReceive(result))
        switch queueStatus {
            case .enqueued:
                receiveStateTask.finish()
            case .terminated:
                await resolution.set(value: .failure(PublisherError.completed))
                throw PublisherError.completed
            case .dropped:
                await resolution.set(value: .failure(PublisherError.enqueueError))
                throw PublisherError.enqueueError
            @unknown default:
                await resolution.set(value: .failure(PublisherError.enqueueError))
                throw PublisherError.enqueueError
        }
    }

    @Sendable func send(_ result: Result<Output, Swift.Error>) async throws -> Void {
        try await receive(result)
    }

    @Sendable func succeed(_ value: Output) async throws -> Void {
        try await receive(.success(value))
    }

    @Sendable func fail(_ error: Swift.Error) async throws -> Void {
        try await receive(.failure(error))
    }

    @Sendable func finish() -> Void {
        stateTask.finish()
    }
}
