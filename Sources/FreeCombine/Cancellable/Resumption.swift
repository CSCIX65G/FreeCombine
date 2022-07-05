//
//  Resumption.swift
//  
//
//  Created by Van Simmons on 6/15/22.
//
@preconcurrency import Atomics

public final class Resumption<Output: Sendable>: Sendable {
    public enum Error: Swift.Error {
        case leaked
        case alreadyResumed
    }

    private let deallocGuard: ManagedAtomic<Bool>
    private let file: StaticString
    private let line: UInt
    private let deinitBehavior: DeinitBehavior
    private let continuation: CheckedContinuation<Output, Swift.Error>

    init(
        file: StaticString = #file,
        line: UInt = #line,
        deinitBehavior: DeinitBehavior = .assert,
        continuation: CheckedContinuation<Output, Swift.Error>
    ) {
        self.deallocGuard = ManagedAtomic<Bool>(false)
        self.file = file
        self.line = line
        self.deinitBehavior = deinitBehavior
        self.continuation = continuation
    }

    public var hasResumed: Bool {
        deallocGuard.load(ordering: .sequentiallyConsistent)
    }

    deinit {
        switch deinitBehavior {
            case .assert:
                assert(hasResumed, "ABORTING DUE TO LEAKED \(type(of: Self.self)) CREATED @ \(file): \(line)")
            case .logAndCancel:
                if !hasResumed { print("CANCELLING LEAKED \(type(of: Self.self)) CREATED @ \(file): \(line)") }
            case .silentCancel:
                ()
        }
        if !hasResumed { continuation.resume(throwing: Error.leaked) }
    }

    public func resume(returning output: Output) -> Void {
        let (success, _) = deallocGuard.compareExchange(expected: false, desired: true, ordering: .sequentiallyConsistent)
        assert(success, "\(type(of: Self.self)) FAILED. ALREADY RESUMED")
        continuation.resume(returning: output)
    }

    public func resume(throwing error: Swift.Error) -> Void {
        let (success, _) = deallocGuard.compareExchange(expected: false, desired: true, ordering: .sequentiallyConsistent)
        assert(success, "\(type(of: Self.self)) FAILED. ALREADY RESUMED")
        continuation.resume(throwing: error)
    }
}

extension Resumption where Output == Void {
    public func resume() -> Void {
        let (success, _) = deallocGuard.compareExchange(expected: false, desired: true, ordering: .acquiring)
        defer { deallocGuard.store(true, ordering: .releasing) }
        assert(success, "RESUMPTION FAILED TO RETURN. ALREADY RESUMED")
        continuation.resume(returning: ())
    }
}

public func withResumption<Output>(
    file: StaticString = #file,
    line: UInt = #line,
    deinitBehavior: DeinitBehavior = .assert,
    _ f: (Resumption<Output>) -> Void
) async throws -> Output {
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Output, Swift.Error>) -> Void in
        f(.init(
            file: file,
            line: line,
            deinitBehavior: deinitBehavior,
            continuation: continuation
        ))
    }
}
