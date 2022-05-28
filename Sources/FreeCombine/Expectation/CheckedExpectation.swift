//
//  CheckedExpectation.swift
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

    public init(name: String = "") async {
        let localState = State()
        var localTask: Task<Arg, Swift.Error>!
        await localState.set(resumption: await withCheckedContinuation { cc in
            localTask = Task<Arg, Swift.Error> {
                try await withTaskCancellationHandler(handler: { Task { try await localState.cancel() } }) {
                    do { return try await withUnsafeThrowingContinuation(cc.resume) }
                    catch { throw error }
                }
            }
        })
        task = localTask
        state = localState
    }

    deinit { cancel() }
    public var isCancelled: Bool { task.isCancelled }
    public func cancel() -> Void { task.cancel() }

    public func status() async -> Status { await state.status }
    public func complete(_ arg: Arg) async throws -> Void { try await state.complete(arg) }
    public func fail(_ error: Error) async throws -> Void { try await state.fail(error) }

    public var result: Result<Arg, Swift.Error> {
        get async { await task.result }
    }
    
    public var value: Arg {
        get async throws {
            do { return try await task.value }
            catch { throw error }
        }
    }
}

extension CheckedExpectation where Arg == Void {
    nonisolated public func complete() async throws -> Void {
        try await state.complete(())
    }
}
