//
//  Server.swift
//  
//
//  Created by Van Simmons on 2/11/22.
//

public struct Server<Input, Output, E: Error> {
    public enum Error: Swift.Error, CaseIterable {
        case terminated
        case dropped
        case cancelled
        case taskFailure
        case noValues
    }

    public enum Result {
        case value(Output)
        case failure(Error)
        case terminated
        case cancelled
    }

    public actor State {
        public enum Status: Equatable {
            case cancelled
            case terminated
            case running
        }

        public private(set) var status: Status = .running
        public init() { }

        public func cancel() { status = .cancelled }
        public func terminate() { status = .terminated }
    }

    public struct WorkItem {
        public let input: Input
        public let resumption: UnsafeContinuation<Result, E>
        public init(input: Input, resumption: UnsafeContinuation<Result, E>) {
            self.input = input
            self.resumption = resumption
        }
    }

    public private(set) var serverState: State
    public let service: Service<WorkItem>
    public let task: Task<Output, Swift.Error>

    public init(
        service: Service<WorkItem>,
        task: Task<Output, Swift.Error>
    ) {
        self.serverState = .init()
        self.service = service
        self.task = task
    }

    public init(
        onCancel: @Sendable @escaping () -> Void = { },
        buffering: AsyncStream<WorkItem>.Continuation.BufferingPolicy = .unbounded,
        onTermination: (@Sendable (AsyncStream<WorkItem>.Continuation.Termination) -> Void)? = .none,
        invoking call: @escaping (Input) async throws -> Output
    ) where E == Swift.Error {
        let localServiceState = State()
        let localTerm: @Sendable (AsyncStream<WorkItem>.Continuation.Termination) -> Void = { termination in
            Task { await localServiceState.terminate() }
            onTermination?(termination)
        }
        let localService = Service<WorkItem>(
            buffering: buffering,
            onTermination: localTerm
        )
        self.task = .init { try await withTaskCancellationHandler(handler: { }) {
            var result: Swift.Result<Output, Swift.Error> = .failure(Error.noValues)
            for await item in localService {
                switch await localServiceState.status {
                    case .cancelled:
                        item.resumption.resume(returning: .cancelled)
                        result = .failure(Error.cancelled)
                        continue
                    case .terminated:
                        item.resumption.resume(returning: .terminated)
                        result = .failure(Error.terminated)
                        continue
                    case .running:
                        do {
                            let value = try await call(item.input)
                            item.resumption.resume(returning: .value(value))
                            result = .success(value)
                        } catch {
                            item.resumption.resume(throwing: error)
                            result = .failure(Error.taskFailure)
                            localService.finish()
                            await localServiceState.cancel()
                        }
                }
            }
            switch result {
                case let .success(value): return value
                case let .failure(error): throw error
            }
        } }
        self.serverState = localServiceState
        self.service = localService
    }

    public init(
        onCancel: @Sendable @escaping () -> Void =  { },
        buffering: AsyncStream<WorkItem>.Continuation.BufferingPolicy = .unbounded,
        onTermination: (@Sendable (AsyncStream<WorkItem>.Continuation.Termination) -> Void)? = .none,
        withoutWaiting call: @escaping (Input) async throws -> Output
    ) where Output == Void, E == Swift.Error {
        let localServiceState = State()
        let localTerm: @Sendable (AsyncStream<WorkItem>.Continuation.Termination) -> Void = { termination in
            Task { await localServiceState.terminate() }
            onTermination?(termination)
        }
        let localService = Service<WorkItem>(
            buffering: buffering,
            onTermination: localTerm
        )
        self.serverState = localServiceState
        self.task = .init { try await withTaskCancellationHandler(handler: { } ) {
            var result: Swift.Result<Output, Swift.Error> = .failure(Error.taskFailure)
            for await item in localService {
                switch await localServiceState.status {
                    case .cancelled:
                        item.resumption.resume(returning: .cancelled)
                        result = .failure(Error.cancelled)
                        continue
                    case .terminated:
                        item.resumption.resume(returning: .terminated)
                        result = .failure(Error.terminated)
                        continue
                    case .running:
                        do {
                            item.resumption.resume(returning: .value(()))
                            try await call(item.input)
                            result = .success(())
                        } catch {
                            item.resumption.resume(throwing: error)
                            localService.finish()
                            await localServiceState.cancel()
                        }
                }
            }
            switch result {
                case let .success(value): return value
                case let .failure(error): throw error
            }
        } }
        self.service = localService
    }

    public func finish() {
        service.finish()
    }

    public func cancel() {
        service.finish()
        task.cancel()
    }
}

public extension Server {
    @discardableResult
    @Sendable private nonisolated func callAsFunction(_ a: Input) async throws -> Result where E == Swift.Error {
        try await withUnsafeThrowingContinuation({ c in
            let item = WorkItem(input: a, resumption: c)
            switch service.yield(item) {
                case .enqueued:
                    ()
                case .dropped:
                    c.resume(returning: .failure(Error.dropped))
                case .terminated:
                    c.resume(returning: .failure(Error.terminated))
                @unknown default:
                    fatalError("Unhandled default in \(#file):\(#line)")
            }
        })
    }

    @discardableResult
    @Sendable nonisolated func callAsFunction(_ a: Input) async throws -> Output where E == Swift.Error {
        let result: Result = try await self(a)
        switch result {
            case let .value(value):
                return value
            case let .failure(error):
                throw error
            case .cancelled:
                throw Error.cancelled
            case .terminated:
                throw Error.terminated
        }
    }
}
