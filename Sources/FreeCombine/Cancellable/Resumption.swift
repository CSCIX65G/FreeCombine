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
    private let continuation: UnsafeContinuation<Output, Swift.Error>

    init(
        file: StaticString = #file,
        line: UInt = #line,
        deinitBehavior: DeinitBehavior = .assert,
        continuation: UnsafeContinuation<Output, Swift.Error>
    ) {
        self.deallocGuard = ManagedAtomic<Bool>(false)
        self.file = file
        self.line = line
        self.deinitBehavior = deinitBehavior
        self.continuation = continuation
    }

    deinit {
        switch deinitBehavior {
            case .assert:
                assert(
                    deallocGuard.load(ordering: .sequentiallyConsistent),
                    "ABORTING DUE TO LEAKED \(type(of: Self.self)):\(self) CREATED @ \(file): \(line)"
                )
            case .logAndCancel:
                if !deallocGuard.load(ordering: .sequentiallyConsistent) {
                    print("RESUMING LEAKED \(type(of: Self.self)) CREATED @ \(file): \(line)")
                }
            case .silentCancel:
                ()
        }
        if !deallocGuard.load(ordering: .sequentiallyConsistent) {
            continuation.resume(throwing: Error.leaked)
        }
    }

    public func resume(returning output: Output) -> Void {
        let (success, _) = deallocGuard.compareExchange(expected: false, desired: true, ordering: .sequentiallyConsistent)
        assert(success, "\(type(of: Self.self)) FAILED. ALREADY RESUMED \(type(of: Self.self)):\(self) CREATED @ \(file): \(line)")
        continuation.resume(returning: output)
    }

    public func resume(throwing error: Swift.Error) -> Void {
        let (success, _) = deallocGuard.compareExchange(expected: false, desired: true, ordering: .sequentiallyConsistent)
        assert(success, "\(type(of: Self.self)) FAILED. ALREADY RESUMED \(type(of: Self.self)):\(self) CREATED @ \(file): \(line)")
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
    _ resume: (Resumption<Output>) -> Void
) async throws -> Output {
    try await withUnsafeThrowingContinuation { (continuation: UnsafeContinuation<Output, Swift.Error>) -> Void in
        resume(.init(
            file: file,
            line: line,
            deinitBehavior: deinitBehavior,
            continuation: continuation
        ))
    }
}
