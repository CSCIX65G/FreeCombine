//
//  Subject.swift
//  
//
//  Created by Van Simmons on 6/28/22.
//
//  Copyright 2022, ComputeCycles, LLC
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//
public final class Subject<Output: Sendable> {
    private let stateTask: StateTask<DistributorState<Output>, DistributorState<Output>.Action>
    private let receiveStateTask: StateTask<DistributorReceiveState<Output>, DistributorReceiveState<Output>.Action>

    public let function: StaticString
    public let file: StaticString
    public let line: UInt
    public let deinitBehavior: DeinitBehavior

    init(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line,
        deinitBehavior: DeinitBehavior = .assert,
        buffering: AsyncStream<DistributorReceiveState<Output>.Action>.Continuation.BufferingPolicy = .bufferingOldest(1),
        stateTask: StateTask<DistributorState<Output>, DistributorState<Output>.Action>
    ) async throws {
        self.function = function
        self.file = file
        self.line = line
        self.deinitBehavior = deinitBehavior
        self.stateTask = stateTask
        self.receiveStateTask = try await Channel(buffering: buffering).stateTask(
            file: file,
            line: line,
            deinitBehavior: deinitBehavior,
            initialState: DistributorReceiveState<Output>.create(distributorChannel: stateTask.channel),
            reducer: .init(
                onCompletion: DistributorReceiveState<Output>.complete,
                disposer: DistributorReceiveState<Output>.dispose,
                reducer: DistributorReceiveState<Output>.reduce
            )
        )
    }

    deinit {
        let shouldCancel = !(isCompleting || isCancelled)
        switch deinitBehavior {
            case .assert:
                assert(!shouldCancel, "ABORTING DUE TO LEAKED \(type(of: Self.self))  CREATED in \(function) @ \(file): \(line)")
            case .logAndCancel:
                if shouldCancel { print("CANCELLING LEAKED \(type(of: Self.self))  CREATED in \(function) @ \(file): \(line)") }
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
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line,
        _ downstream: @escaping @Sendable (AsyncStream<Output>.Result) async throws -> Demand
    ) async throws -> Cancellable<Demand> {
        try await withResumption { resumption in
            let queueStatus = stateTask.send(.subscribe(downstream, resumption))
            switch queueStatus {
                case .enqueued:
                    ()
                case .terminated:
                    assert(false, "Sending subscription to terminated Subject", file: file, line: line)
                    resumption.resume(throwing: PublisherError.completed)
                case .dropped:
                    assert(false, "Dropped subscription to Subject", file: file, line: line)
                    resumption.resume(throwing: PublisherError.enqueueError)
                @unknown default:
                    resumption.resume(throwing: PublisherError.enqueueError)
            }
        }
    }
}

extension Subject {
    func blockingReceive(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line,
        _ result: AsyncStream<Output>.Result
    ) async throws -> Int {
        let count: Int = try await withResumption { resumption in
            let queueStatus = receiveStateTask.send(.blockingReceive(result, resumption))
            switch queueStatus {
                case .enqueued:
                    ()
                case .terminated:
                    assert(false, "Sending \(result) to terminated Subject", file: file, line: line)
                    resumption.resume(throwing: PublisherError.completed)
                case .dropped:
                    assert(false, "Dropped \(result) on blocking send to Subject", file: file, line: line)
                    resumption.resume(throwing: PublisherError.enqueueError)
                @unknown default:
                    resumption.resume(throwing: PublisherError.enqueueError)
            }
        }
        return count
    }

    func nonblockingReceive(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line,
        _ result: AsyncStream<Output>.Result
    ) throws -> Void {
        let queueStatus = receiveStateTask.send(.nonBlockingReceive(result))
        switch queueStatus {
            case .enqueued:
                ()
            case .terminated:
                assert(false, "Sending \(result) to terminated Subject", file: file, line: line)
                throw PublisherError.completed
            case .dropped:
                assert(false, "Dropped \(result) on nonblocking send to Subject", file: file, line: line)
                throw PublisherError.enqueueError
            @unknown default:
                throw PublisherError.enqueueError
        }
    }
}

public extension Subject {
    func publisher(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line,
        deinitBehavior: DeinitBehavior = .assert
    ) -> Publisher<Output> {
        .init(file: file, line: line, deinitBehavior: deinitBehavior, stateTask: stateTask)
    }

    var asyncPublisher: Publisher<Output> {
        get { .init(file: file, line: line, deinitBehavior: deinitBehavior, stateTask: stateTask) }
    }

    @discardableResult
    @Sendable func blockingSend(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line,
        _ result: AsyncStream<Output>.Result
    ) async throws -> Int {
        try await blockingReceive(file: file, line: line, result)
    }
    @discardableResult
    @Sendable func blockingSend(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line,
        _ value: Output
    ) async throws -> Int {
        try await blockingReceive(file: file, line: line, .value(value))
    }

    @Sendable func nonblockingSend(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line,
        _ result: AsyncStream<Output>.Result
    ) throws -> Void {
        try nonblockingReceive(file: file, line: line, result)
    }
    @Sendable func nonblockingSend(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line,
        _ value: Output
    ) throws -> Void {
        try nonblockingReceive(file: file, line: line, .value(value))
    }
}
