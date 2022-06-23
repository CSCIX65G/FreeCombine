//
//  Cancellable.swift
//  
//
//  Created by Van Simmons on 5/18/22.
//
@preconcurrency import Atomics

public enum DeinitBehavior: Sendable {
    case assert
    case logAndCancel
    case silentCancel
}

// Can't be a protocol bc we have to implement deinit
public final class Cancellable<Output: Sendable>: Sendable {
    private let task: Task<Output, Swift.Error>
    private let deallocGuard: ManagedAtomic<Bool>

    public let file: StaticString
    public let line: UInt
    public let deinitBehavior: DeinitBehavior

    public var isCancelled: Bool { task.isCancelled }
    public var isCompleting: Bool { deallocGuard.load(ordering: .sequentiallyConsistent) }
    public var value: Output {  get async throws { try await task.value } }
    public var result: Result<Output, Swift.Error> {  get async { await task.result } }

    @Sendable public func cancel() -> Void {
        guard !isCompleting else { return }
        task.cancel()
    }
    @Sendable public func cancelAndAwaitValue() async throws -> Output {
        cancel()
        return try await task.value
    }
    @Sendable public func cancelAndAwaitResult() async -> Result<Output, Swift.Error> {
        cancel()
        return await task.result
    }

    init(
        file: StaticString = #file,
        line: UInt = #line,
        deinitBehavior: DeinitBehavior = .assert,
        operation: @Sendable @escaping () async throws -> Output
    ) {
        let atomic = ManagedAtomic<Bool>(false)
        self.deallocGuard = atomic
        self.file = file
        self.line = line
        self.deinitBehavior = deinitBehavior
        self.task = .init {
            do {
                let retVal = try await operation()
                atomic.store(true, ordering: .sequentiallyConsistent)
                return retVal
            }
            catch {
                atomic.store(true, ordering: .sequentiallyConsistent)
                throw error
            }
        }
    }

    deinit {
        let shouldCancel = !(isCompleting || task.isCancelled)
        switch deinitBehavior {
            case .assert:
                assert(!shouldCancel, "ABORTING DUE TO LEAKED \(type(of: Self.self)) CREATED @ \(file): \(line)")
            case .logAndCancel:
                if shouldCancel { print("CANCELLING LEAKED \(type(of: Self.self)) CREATED @ \(file): \(line)") }
            case .silentCancel:
                ()
        }
        if shouldCancel { task.cancel() }
    }
}

public extension Cancellable {
    static func join<B>(
        file: StaticString = #file,
        line: UInt = #line,
        _ outer: Cancellable<Cancellable<B>>
    ) -> Cancellable<B> {
        .init(file: file, line: line, operation: {
            try await withTaskCancellationHandler(handler: {
                Task<Void, Swift.Error> { try! await outer.value.cancel() }
            }, operation: {
                return try await outer.value.value
            })
        })
    }

    static func join(
        file: StaticString = #file,
        line: UInt = #line,
        _ generator: @escaping () async throws -> Cancellable<Output>
    ) async throws -> Cancellable<Output> {
        var returnValue: Cancellable<Output>!
        let _: Void = try await withResumption { resumption in
            returnValue = .init(file: file, line: line, operation: {
                let outer = try await generator()
                return try await withTaskCancellationHandler(handler: {
                    Task<Void, Swift.Error> { outer.cancel() }
                }, operation: {
                    resumption.resume()
                    return try await outer.value
                })
            })
        }
        return returnValue
    }

    func map<B>(
        file: StaticString = #file,
        line: UInt = #line,
        _ f: @escaping (Output) async -> B
    ) -> Cancellable<B> {
        let inner = self
        return .init(file: file, line: line) {
            try await withTaskCancellationHandler(handler: { Task { inner.cancel() } }) {
                try await f(inner.value)
            }
        }
    }

    func join<B>(
        file: StaticString = #file,
        line: UInt = #line
    ) -> Cancellable<B> where Output == Cancellable<B> {
        Self.join(file: file, line: line, self)
    }

    func flatMap<B>(
        _ f: @escaping (Output) async -> Cancellable<B>,
        file: StaticString = #file,
        line: UInt = #line
    ) -> Cancellable<B> {
        self.map(file: file, line: line, f).join(file: file, line: line)
    }
}
