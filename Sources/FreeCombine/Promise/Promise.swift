//
//  Promise.swift
//
//
//  Created by Van Simmons on 6/28/22.
//
public final class Promise<Output: Sendable> {
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
    public func fail(_ error: Error) async throws -> Void {
        try await stateTask.fail(error)
    }
    public func failAndAwaitResult(_ error: Error) async throws -> Result<PromiseState<Output>, Swift.Error> {
        try await stateTask.fail(error)
        return await stateTask.result
    }
}

extension Promise {
    func subscribe(
        _ downstream: @Sendable @escaping (Result<Output, Swift.Error>) async throws -> Void
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
        get { .init(file: file, line: line, deinitBehavior: deinitBehavior, stateTask: stateTask) }
    }

    func receive(
        _ result: Result<Output, Swift.Error>
    ) async throws -> Int {
        let count: Int = try await withResumption { resumption in
            let queueStatus = receiveStateTask.send(.receive(result, resumption))
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
        return count
    }

    func receive(
        _ result: Result<Output, Swift.Error>
    ) throws -> Void {
        let queueStatus = receiveStateTask.send(.nonBlockingReceive(result))
        switch queueStatus {
            case .enqueued:
                ()
            case .terminated:
                throw PublisherError.completed
            case .dropped:
                throw PublisherError.enqueueError
            @unknown default:
                throw PublisherError.enqueueError
        }
    }

    @discardableResult
    @Sendable func send(_ result: Result<Output, Swift.Error>) async throws -> Int {
        try await receive(result)
    }
    @discardableResult
    @Sendable func send(_ value: Output) async throws -> Int {
        try await receive(.success(value))
    }
    @Sendable func send(_ result: Result<Output, Swift.Error>) throws -> Void {
        try receive(result)
    }
    @Sendable func send(_ value: Output) throws -> Void {
        try receive(.success(value))
    }
}
