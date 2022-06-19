//
//  File.swift
//  
//
//  Created by Van Simmons on 6/15/22.
//

@preconcurrency import Atomics

public final class Resumption<Output: Sendable>: Sendable {
    private let deallocGuard: ManagedAtomic<Bool>

    public let file: StaticString
    public let line: UInt
    public let deinitBehavior: DeinitBehavior

    init(
        file: StaticString = #file,
        line: UInt = #line,
        deinitBehavior: DeinitBehavior = .assert,
        operation: @Sendable @escaping () async throws -> Output
    ) async {
        let atomic = ManagedAtomic<Bool>(false)
        self.deallocGuard = atomic
        self.file = file
        self.line = line
        self.deinitBehavior = deinitBehavior
//        self.con = .init {
//            defer { atomic.store(true, ordering: .sequentiallyConsistent) }
//            do { return try await operation() }
//            catch { throw error }
//        }
    }

    deinit {
//        let shouldCancel = !(isCompleting || task.isCancelled)
//        switch deinitBehavior {
//            case .assert:
//                assert(!shouldCancel, "ABORTING DUE TO LEAKED TASK CREATED @ \(file): \(line)")
//            case .log:
//                if shouldCancel { print("CANCELLING LEAKED TASK CREATED @ \(file): \(line)") }
//            case .none:
//                ()
//        }
//        if shouldCancel { task.cancel() }
    }
}
