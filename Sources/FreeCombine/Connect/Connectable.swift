//
//  Connectable.swift
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
public final class Connectable<Output: Sendable> {
    private let stateTask: StateTask<ConnectableState<Output>, ConnectableState<Output>.Action>
    private let distributeStateTask: StateTask<ConnectableRepeaterState<Output>, ConnectableRepeaterState<Output>.Action>

    public let function: StaticString
    public let file: StaticString
    public let line: UInt
    public let deinitBehavior: DeinitBehavior

    init(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line,
        deinitBehavior: DeinitBehavior = .assert,
        repeater: Channel<ConnectableRepeaterState<Output>.Action>,
        stateTask: StateTask<ConnectableState<Output>, ConnectableState<Output>.Action>
    ) async throws {
        self.function = function
        self.file = file
        self.line = line
        self.deinitBehavior = deinitBehavior
        self.stateTask = stateTask
        self.distributeStateTask = try await repeater.stateTask(
            file: file,
            line: line,
            deinitBehavior: deinitBehavior,
            initialState: ConnectableRepeaterState<Output>.create(distributorChannel: stateTask.channel),
            reducer: .init(
                onCompletion: ConnectableRepeaterState<Output>.complete,
                disposer: ConnectableRepeaterState<Output>.dispose,
                reducer: ConnectableRepeaterState<Output>.reduce
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
            distributeStateTask.cancel()
            stateTask.cancel()
        }
    }

    public var isCancelled: Bool {
        @Sendable get {
            stateTask.isCancelled && distributeStateTask.isCancelled
        }
    }
    public var isCompleting: Bool {
        @Sendable get {
            stateTask.isCompleting && distributeStateTask.isCompleting
        }
    }
    public var value: ConnectableState<Output> {
        get async throws {
            _ = await distributeStateTask.result
            return try await stateTask.value
        }
    }

    public var result: Result<ConnectableState<Output>, Swift.Error> {
        get async {
            _ = await distributeStateTask.result
            return await stateTask.result
        }
    }

    public func finish() async throws -> Void {
        distributeStateTask.finish()
        _ = await distributeStateTask.result
        try await stateTask.finish()
        _ = await stateTask.result
    }
    public func finishAndAwaitResult() async throws -> Void {
        distributeStateTask.finish()
        _ = await distributeStateTask.result
        try await stateTask.finish()
        _ = await stateTask.result
    }
    public func cancel() async throws -> Void {
        distributeStateTask.cancel()
        _ = await distributeStateTask.result
        try await stateTask.cancel()
    }
    public func cancelAndAwaitResult() async throws -> Result<ConnectableState<Output>, Swift.Error> {
        distributeStateTask.cancel()
        _ = await distributeStateTask.result
        try await stateTask.cancel()
        return await stateTask.result
    }
    public func fail(_ error: Error) async throws -> Void {
        distributeStateTask.cancel()
        _ = await distributeStateTask.result
        try await stateTask.fail(error)
    }
    public func failAndAwaitResult(_ error: Error) async throws -> Result<ConnectableState<Output>, Swift.Error> {
        distributeStateTask.cancel()
        _ = await distributeStateTask.result
        try await stateTask.fail(error)
        return await stateTask.result
    }
}

public extension Connectable {
    func publisher(
        function: StaticString = #function,
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
        let _: Void = try await withResumption({ continuation in
            let queueStatus = stateTask.send(.disconnect(continuation))
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
        })
        distributeStateTask.cancel()
        _ = await distributeStateTask.result
    }

    func pause() async throws -> Void {
        return try await withResumption({ continuation in
            let queueStatus = stateTask.send(.pause(continuation))
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
        })
    }

    func resume() async throws -> Void {
        return try await withResumption({ continuation in
            let queueStatus = stateTask.send(.resume(continuation))
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
        })
    }

    func receive(
        _ result: AsyncStream<Output>.Result
    ) async throws -> Int {
        let count: Int = try await withResumption { resumption in
            let queueStatus = distributeStateTask.send(.receive(result, resumption))
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

