//
//  Distributor.swift
//  
//
//  Created by Van Simmons on 6/28/22.
//
public final class Distributor<Output: Sendable> {
    private let stateTask: StateTask<DistributorState<Output>, DistributorState<Output>.Action>
    private let subscribeStateTask: StateTask<RepeatSubscribeState<Output>, RepeatSubscribeState<Output>.Action>
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
        self.subscribeStateTask = try await Channel<RepeatSubscribeState<Output>.Action>(buffering: .unbounded).stateTask(
            file: file,
            line: line,
            deinitBehavior: deinitBehavior,
            initialState: RepeatSubscribeState<Output>.create(distributorChannel: stateTask.channel),
            reducer: .init(
                onCompletion: RepeatSubscribeState<Output>.complete,
                disposer: RepeatSubscribeState<Output>.dispose,
                reducer: RepeatSubscribeState<Output>.reduce
            )
        )
        self.receiveStateTask = try await Channel<RepeatReceiveState<Output>.Action>(buffering: buffering).stateTask(
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
            stateTask.cancel()
            subscribeStateTask.cancel()
            receiveStateTask.cancel()
        }
    }

    public var isCancelled: Bool {
        @Sendable get {
            stateTask.isCancelled && subscribeStateTask.isCancelled && receiveStateTask.isCancelled
        }
    }
    public var isCompleting: Bool {
        @Sendable get {
            stateTask.isCompleting && subscribeStateTask.isCompleting && receiveStateTask.isCompleting
        }
    }
    public var value: DistributorState<Output> {
        get async throws {
            _ = await subscribeStateTask.result
            _ = await receiveStateTask.result
            return try await stateTask.value
        }
    }
    public var result: Result<DistributorState<Output>, Swift.Error> {
        get async {
            _ = await subscribeStateTask.result
            _ = await receiveStateTask.result
            return await stateTask.result
        }
    }
    public func finish() async throws -> Void {
        subscribeStateTask.finish()
        receiveStateTask.finish()
        try await stateTask.finish()
    }
    public func finishAndAwaitResult() async throws -> Void {
        subscribeStateTask.finish()
        receiveStateTask.finish()
        try await stateTask.finish()
        _ = await stateTask.result
    }
    public func cancel() async throws -> Void {
        subscribeStateTask.cancel()
        receiveStateTask.cancel()
        try await stateTask.cancel()
    }
    public func cancelAndAwaitResult() async throws -> Result<DistributorState<Output>, Swift.Error> {
        subscribeStateTask.cancel()
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

extension Distributor {
    func subscribe(
        _ downstream: @Sendable @escaping (AsyncStream<Output>.Result) async throws -> Demand
    ) async throws -> Cancellable<Demand> {
        try await withResumption { resumption in
            let queueStatus = subscribeStateTask.send(.subscribe(downstream, resumption))
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

public extension Distributor {
    func publisher(
        file: StaticString = #file,
        line: UInt = #line,
        deinitBehavior: DeinitBehavior = .assert
    ) -> Publisher<Output> {
        .init(file: file, line: line, deinitBehavior: deinitBehavior, stateTask: stateTask)
    }

    func receive(
        _ result: AsyncStream<Output>.Result
    ) async throws -> Void {
        let _: Void = try await withResumption { resumption in
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
    }

    @Sendable func send(_ result: AsyncStream<Output>.Result) async throws -> Void {
        try await receive(result)
    }
    @Sendable func send(_ value: Output) async throws -> Void {
        try await receive(.value(value))
    }
}
