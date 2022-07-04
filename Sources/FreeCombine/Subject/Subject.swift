//
//  Distributor.swift
//  
//
//  Created by Van Simmons on 6/28/22.
//
public final class Subject<Output: Sendable> {
    private let stateTask: StateTask<DistributorState<Output>, DistributorState<Output>.Action>
    private let receiveStateTask: StateTask<RepeatReceiveState<Output>, RepeatReceiveState<Output>.Action>

    let file: StaticString
    let line: UInt
    let deinitBehavior: DeinitBehavior

    init(
        file: StaticString = #file,
        line: UInt = #line,
        deinitBehavior: DeinitBehavior = .assert,
        buffering: AsyncStream<RepeatReceiveState<Output>.Action>.Continuation.BufferingPolicy = .bufferingOldest(1),
        stateTask: StateTask<DistributorState<Output>, DistributorState<Output>.Action>
    ) async throws {
        self.file = file
        self.line = line
        self.deinitBehavior = deinitBehavior
        self.stateTask = stateTask
        self.receiveStateTask = try await Channel(buffering: buffering).stateTask(
            file: file,
            line: line,
            deinitBehavior: deinitBehavior,
            initialState: RepeatReceiveState<Output>.create(distributorChannel: stateTask.channel),
            reducer: .init(
                onCompletion: RepeatReceiveState<Output>.complete,
                disposer: RepeatReceiveState<Output>.dispose,
                reducer: RepeatReceiveState<Output>.reduce
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
    public var value: DistributorState<Output> {
        get async throws {
            _ = await receiveStateTask.result
            return try await stateTask.value
        }
    }
    public var result: Result<DistributorState<Output>, Swift.Error> {
        get async {
            _ = await receiveStateTask.result
            return await stateTask.result
        }
    }
    public func finish() async throws -> Void {
        receiveStateTask.finish()
        try await stateTask.finish()
    }
    public func finishAndAwaitResult() async throws -> Void {
        receiveStateTask.finish()
        try await stateTask.finish()
        _ = await stateTask.result
    }
    public func cancel() async throws -> Void {
        receiveStateTask.cancel()
        try await stateTask.cancel()
    }
    public func cancelAndAwaitResult() async throws -> Result<DistributorState<Output>, Swift.Error> {
        receiveStateTask.cancel()
        try await stateTask.cancel()
        return await stateTask.result
    }
    public func fail(_ error: Error) async throws -> Void {
        try await stateTask.fail(error)
    }
    public func failAndAwaitResult(_ error: Error) async throws -> Result<DistributorState<Output>, Swift.Error> {
        try await stateTask.fail(error)
        return await stateTask.result
    }
}

extension Subject {
    func subscribe(
        _ downstream: @Sendable @escaping (AsyncStream<Output>.Result) async throws -> Demand
    ) async throws -> Cancellable<Demand> {
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

public extension Subject {
    func publisher(
        file: StaticString = #file,
        line: UInt = #line,
        deinitBehavior: DeinitBehavior = .assert
    ) -> Publisher<Output> {
        .init(file: file, line: line, deinitBehavior: deinitBehavior, stateTask: stateTask)
    }

    func receive(
        _ result: AsyncStream<Output>.Result
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

    @discardableResult
    @Sendable func send(_ result: AsyncStream<Output>.Result) async throws -> Int {
        try await receive(result)
    }
    @discardableResult
    @Sendable func send(_ value: Output) async throws -> Int {
        try await receive(.value(value))
    }
}