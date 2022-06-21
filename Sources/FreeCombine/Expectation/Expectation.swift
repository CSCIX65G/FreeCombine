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
    private(set) var resumption: Resumption<Arg>
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
        self.resumption = try! await withResumption { outer in
            localCancellable = .init {
                do { return try await withResumption(outer.resume) }
                catch { throw error }
            }
        }
        self.cancellable = localCancellable
    }

    deinit {
        let shouldCancel = status == .waiting
        switch deinitBehavior {
            case .assert:
                assert(!shouldCancel, "ABORTING DUE TO LEAKED \(type(of: Self.self)) CREATED @ \(file): \(line)")
            case .log:
                if shouldCancel { print("CANCELLING LEAKED \(type(of: Self.self)) CREATED @ \(file): \(line)") }
            case .silent:
                ()
        }
        if shouldCancel { try? cancel() }
    }

    private func set(status newStatus: Status) throws -> Resumption<Arg> {
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
        .init(rawValue: atomic.load(ordering: .sequentiallyConsistent))!
    }

    public var isCancelled: Bool {
        cancellable.isCancelled
    }

    public var result: Result<Arg, Swift.Error> {
        get async { await cancellable.result }
    }
    
    public var value: Arg {
        get async throws { try await cancellable.value  }
    }

    public func cancel() throws {
        try set(status: .cancelled).resume(throwing: Error.cancelled)
    }
    public func complete(_ arg: Arg) throws {
        try set(status: .completed).resume(returning: arg)
    }
    func fail(_ error: Swift.Error) throws {
        try set(status: .failed).resume(throwing: error)
    }
}

extension Expectation where Arg == Void {
    public func complete() async throws -> Void {
        try complete(())
    }
}
