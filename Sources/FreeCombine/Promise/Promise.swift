//
//  Promise.swift
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
import Atomics

public final class Promise<Output: Sendable> {
    fileprivate let resolution: AtomicValueRef<Result<Output, Swift.Error>?> = .init(value: .none)
    private let stateTask: StateTask<PromiseState<Output>, PromiseState<Output>.Action>
    private let receiveStateTask: StateTask<PromiseReceiveState<Output>, PromiseReceiveState<Output>.Action>

    public let function: StaticString
    public let file: StaticString
    public let line: UInt
    public let deinitBehavior: DeinitBehavior

    init(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line,
        deinitBehavior: DeinitBehavior = .assert,
        buffering: AsyncStream<PromiseReceiveState<Output>.Action>.Continuation.BufferingPolicy = .bufferingOldest(1),
        stateTask: StateTask<PromiseState<Output>, PromiseState<Output>.Action>
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
            initialState: PromiseReceiveState<Output>.create(promiseChannel: stateTask.channel),
            reducer: .init(
                reducer: PromiseReceiveState<Output>.reduce,
                disposer: PromiseReceiveState<Output>.dispose,
                finalizer: PromiseReceiveState<Output>.complete
            )
        )
    }

    convenience init(
        function: StaticString = #function,
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
                    reducer: PromiseState<Output>.reduce,
                    disposer: PromiseState<Output>.dispose,
                    finalizer: PromiseState<Output>.complete
                )
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
        if let resolution = resolution.get() {
            return .init { try await downstream(resolution) }
        }
        return try await withResumption { resumption in
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
        function: StaticString = #function,
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

    @Sendable func send(_ result: Result<Output, Swift.Error>) async throws -> Void {
        try resolution.swapIfNone(result)

        let queueStatus = receiveStateTask.send(.nonBlockingReceive(result))
        switch queueStatus {
            case .enqueued:
                receiveStateTask.finish()
            case .terminated:
                try resolution.set(value: .failure(PublisherError.completed))
                throw PublisherError.completed
            case .dropped:
                try resolution.set(value: .failure(PublisherError.enqueueError))
                receiveStateTask.finish()
                throw PublisherError.enqueueError
            @unknown default:
                try resolution.set(value: .failure(PublisherError.enqueueError))
                stateTask.finish()
                throw PublisherError.enqueueError
        }
    }

    @Sendable func succeed(_ value: Output) async throws -> Void {
        try await send(.success(value))
    }

    @Sendable func fail(_ error: Swift.Error) async throws -> Void {
        try await send(.failure(error))
    }

    @Sendable func finish() -> Void {
        stateTask.finish()
    }
}
