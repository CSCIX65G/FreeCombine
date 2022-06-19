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
        case timedOut
        case internalInconsistency
    }

    public enum Status: UInt8, Equatable, RawRepresentable {
        case cancelled
        case completed
        case waiting
        case failed
    }

    private let atomic = ManagedAtomic<UInt8>(Status.waiting.rawValue)
    private(set) var resumption: UnsafeContinuation<Arg, Swift.Error>
    private let cancellable: Cancellable<Arg>
    public let file: StaticString
    public let line: UInt
    public let deinitBehavior: DeinitBehavior

    public init(
        file: StaticString = #file,
        line: UInt = #line,
        deinitBehavior: DeinitBehavior = .assert
    ) async {
        var localCancellable: Cancellable<Arg>!
        self.file = file
        self.line = line
        self.deinitBehavior = deinitBehavior
        self.resumption = await withCheckedContinuation { cc in
            localCancellable = .init {
                do { return try await withUnsafeThrowingContinuation(cc.resume) }
                catch { throw error }
            }
        }
        self.cancellable = localCancellable
    }

    deinit {
        let shouldCancel = status == .waiting
        switch deinitBehavior {
            case .assert:
                assert(!shouldCancel, "ABORTING DUE TO LEAKED EXPECTATION CREATED @ \(file): \(line)")
            case .log:
                if shouldCancel { print("CANCELLING LEAKED EXPECTATION CREATED @ \(file): \(line)") }
            case .none:
                ()
        }
        if shouldCancel { try? cancel() }
    }

    private func change(to newStatus: Status) throws -> UnsafeContinuation<Arg, Swift.Error> {
        let (success, original) = atomic.compareExchange(
            expected: Status.waiting.rawValue,
            desired: newStatus.rawValue,
            ordering: .sequentiallyConsistent
        )
        guard success else {
            switch original {
                case Status.completed.rawValue: throw Error.alreadyCompleted
                case Status.cancelled.rawValue: throw Error.alreadyCancelled
                case Status.failed.rawValue: throw Error.alreadyFailed
                default: throw Error.internalInconsistency
            }
        }
        return resumption
    }

    public var status: Status {
        .init(rawValue: atomic.load(ordering: .relaxed))!
    }


    public var isCancelled: Bool {
        cancellable.isCancelled
    }

    public var result: Result<Arg, Swift.Error> {
        get async { await cancellable.result }
    }
    
    public var value: Arg {
        get async throws {
            do { return try await cancellable.value }
            catch { throw error }
        }
    }

    public func cancel() throws {
        try change(to: .cancelled).resume(throwing: Error.cancelled)
    }
    public func complete(_ arg: Arg) throws {
        try change(to: .completed).resume(returning: arg)
    }
    func fail(_ error: Swift.Error) throws {
        try change(to: .failed).resume(throwing: error)
    }
}

extension Expectation where Arg == Void {
    public func complete() async throws -> Void {
        try complete(())
    }
}
