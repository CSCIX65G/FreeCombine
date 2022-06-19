//
//  CheckedExpectation.swift
//  
//
//  Created by Van Simmons on 1/28/22.
//

import Atomics
public class Expectation<Arg> {
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

        init(_ cancellable: inout Cancellable<Arg>!) async {
            self.resumption = await withCheckedContinuation { cc in
                cancellable = .init {
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

    private let cancellable: Cancellable<Arg>
    private let state: State

    public init() async {
        var localCancellable: Cancellable<Arg>!
        state = await .init(&localCancellable)
        cancellable = localCancellable
    }

    deinit { cancel() }
    public var isCancelled: Bool { cancellable.isCancelled }
    public func cancel() -> Void { cancellable.cancel() }

    public func status() async -> Status { state.status }
    public func complete(_ arg: Arg) throws -> Void { try state.complete(arg) }
    public func fail(_ error: Error) throws -> Void { try state.fail(error) }

    public var result: Result<Arg, Swift.Error> {
        get async { await cancellable.result }
    }
    
    public var value: Arg {
        get async throws {
            do { return try await cancellable.value }
            catch { throw error }
        }
    }
}

extension Expectation where Arg == Void {
    nonisolated public func complete() async throws -> Void {
        try state.complete(())
    }
}
