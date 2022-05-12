//
//  Expectation.swift
//  
//
//  Created by Van Simmons on 1/28/22.
//
public class CheckedExpectation<Arg> {
    public enum Error: Swift.Error, Equatable {
        case alreadyCancelled
        case alreadyCompleted
        case cancelled
        case inconsistentState
        case timedOut
    }

    public enum Status: Equatable {
        case cancelled
        case completed
        case waiting
        case failed
    }

    actor State {
        private(set) var status: Status
        private(set) var resumption: UnsafeContinuation<Arg, Swift.Error>?

        init(status: Status = .waiting) {
            self.status = status
        }

        fileprivate func set(resumption: UnsafeContinuation<Arg, Swift.Error>) {
            status = .waiting
            self.resumption = resumption
        }

        private func validateState() throws -> UnsafeContinuation<Arg, Swift.Error> {
            guard status != .completed else { throw Error.alreadyCompleted }
            guard status != .cancelled else { throw Error.alreadyCancelled }
            guard let resumption = resumption, status == .waiting else { throw Error.inconsistentState }
            return resumption
        }

        func cancel() throws {
            let resumption = try validateState()
            status = .cancelled
            resumption.resume(throwing: Error.cancelled)
        }
        func complete(_ arg: Arg) throws {
            let resumption = try validateState()
            status = .completed
            resumption.resume(returning: arg)
        }
        func fail(_ error: Swift.Error) throws {
            let resumption = try validateState()
            status = .failed
            resumption.resume(throwing: error)
        }
    }

    private let task: Task<Arg, Swift.Error>
    private let state: State

    public init() async {
        let localState = State()
        var localTask: Task<Arg, Swift.Error>!
        let localResumption: UnsafeContinuation<Arg, Swift.Error> = await withCheckedContinuation { cc in
            localTask = Task<Arg, Swift.Error> { try await withTaskCancellationHandler(handler: {
                Task { try await localState.cancel() }
            }) {
                try await withUnsafeThrowingContinuation(cc.resume)
            } }
        }
        await localState.set(resumption: localResumption)
        task = localTask
        state = localState
    }

    deinit {
        cancel()
    }

    public var isCancelled: Bool {
        task.isCancelled
    }

    public func status() async -> Status {
        await state.status
    }

    @discardableResult
    public func result() async -> Result<Arg, Swift.Error> {
        await task.result
    }

    @discardableResult
    public func value() async throws -> Arg {
        try await task.value
    }

    public func cancel() -> Void {
        task.cancel()
    }

    public func complete(_ arg: Arg) async throws -> Void {
        try await state.complete(arg)
    }

    public func fail(_ error: Error) async throws -> Void {
        try await state.fail(error)
    }
}

extension CheckedExpectation where Arg == Void {
    nonisolated public func complete() async throws -> Void {
        try await state.complete(())
    }
}
