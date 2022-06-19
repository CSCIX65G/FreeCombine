//
//  CheckedExpectation.swift
//  
//
//  Created by Van Simmons on 1/28/22.
//

import Atomics
public class CheckedExpectation<Arg> {
    public enum Error: Swift.Error, Equatable {
        case alreadyCancelled
        case alreadyCompleted
        case alreadyFailed
        case cancelled
        case inconsistentState
        case timedOut
    }

    public enum Status: UInt8, Equatable, RawRepresentable {
        case cancelled
        case completed
        case waiting
        case failed
    }

    struct State {
        private let atomic = ManagedAtomic<UInt8>(Status.waiting.rawValue)
        private(set) var resumption: UnsafeContinuation<Arg, Swift.Error>

        init(task: inout Task<Arg, Swift.Error>!, resumption: UnsafeContinuation<Arg, Swift.Error>) async {
            self.resumption = await withCheckedContinuation { cc in
                task = Task<Arg, Swift.Error> {
                    do { return try await withUnsafeThrowingContinuation(cc.resume) }
                    catch { throw error }
                }
            }
        }

        private func change(to newStatus: Status) throws -> UnsafeContinuation<Arg, Swift.Error> {
            let (_, original) = atomic.compareExchange(
                expected: Status.waiting.rawValue,
                desired: newStatus.rawValue,
                ordering: .sequentiallyConsistent
            )
            guard original != Status.completed.rawValue else { throw Error.alreadyCompleted }
            guard original != Status.cancelled.rawValue else { throw Error.alreadyCancelled }
            guard original != Status.failed.rawValue else { throw Error.alreadyFailed }
            return resumption
        }

        public var status: Status {
            .init(rawValue: atomic.load(ordering: .relaxed))!
        }

        func cancel() throws {
            try change(to: .cancelled).resume(throwing: Error.cancelled)
        }
        func complete(_ arg: Arg) throws {
            try change(to: .completed).resume(returning: arg)
        }
        func fail(_ error: Swift.Error) throws {
            try change(to: .failed).resume(throwing: error)
        }
    }

    private let task: Task<Arg, Swift.Error>
    private let state: State

    public init() async {
        var localTask: Task<Arg, Swift.Error>!
        state = await .init(task: &localTask, resumption: await withCheckedContinuation { cc in
            localTask = Task<Arg, Swift.Error> {
                do { return try await withUnsafeThrowingContinuation(cc.resume) }
                catch { throw error }
            }
        })
        task = localTask
    }

    deinit { cancel() }
    public var isCancelled: Bool { task.isCancelled }
    public func cancel() -> Void { task.cancel() }

    public func status() async -> Status { state.status }
    public func complete(_ arg: Arg) throws -> Void { try state.complete(arg) }
    public func fail(_ error: Error) throws -> Void { try state.fail(error) }

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
        try state.complete(())
    }
}
