//: [Previous](@previous)

import _Concurrency

/*:
 Tasks can leak
 */

Task {
    Task {
        try await Task.sleep(nanoseconds: 4_000_000_000)
        print("ending inner task 1")
    }
    Task {
        try await Task.sleep(nanoseconds: 5_000_000_000)
        print("ending inner task 2")
    }
    Task {
        try await Task.sleep(nanoseconds: 3_000_000_000)
        print("ending inner task 3")
    }
    do {
        try await Task.sleep(nanoseconds: 1_000_000_000)
    } catch {
        print("Cancelled the sleep")
    }
    print("ending outer task")
}

/*:
A better approach
 */
public final class Cancellable<Output: Sendable>: Sendable {
    private let _cancel: @Sendable () -> Void
    private let _isCancelled: @Sendable () -> Bool
    private let _value: @Sendable () async throws -> Output
    private let _result: @Sendable () async -> Result<Output, Swift.Error>

    public var isCancelled: Bool {  _isCancelled() }
    public var value: Output {  get async throws { try await _value() } }
    public var result: Result<Output, Swift.Error> {  get async { await _result() } }

    @Sendable public func cancel() -> Void { _cancel() }
    @Sendable public func cancelAndAwaitValue() async throws -> Output {
        _cancel()
        return try await _value()
    }
    @Sendable public func cancelAndAwaitResult() async throws -> Result<Output, Swift.Error> {
        _cancel()
        return await _result()
    }

    init(
        cancel: @escaping @Sendable () -> Void,
        isCancelled: @escaping @Sendable () -> Bool,
        value: @escaping @Sendable () async throws -> Output,
        result: @escaping @Sendable () async -> Result<Output, Swift.Error>
    ) {
        _cancel = cancel
        _isCancelled = isCancelled
        _value = value
        _result = result
    }

    deinit { if !self.isCancelled { self.cancel() } }
}

public extension Cancellable {
    convenience init(task: Task<Output, Swift.Error>) {
        self.init(
            cancel: { task.cancel() },
            isCancelled: { task.isCancelled },
            value: { try await task.value },
            result: { await task.result }
        )
    }
}

Cancellable(task: .init {
    Cancellable(task: .init {
        try await Task.sleep(nanoseconds: 4_000_000_000)
        print("ending inner cancellable 1")
    })
    Cancellable(task: .init {
        try await Task.sleep(nanoseconds: 5_000_000_000)
        print("ending inner cancellable 2")
    })
    Cancellable(task: .init {
        try await Task.sleep(nanoseconds: 3_000_000_000)
        print("ending inner cancellable 3")
    })
    do {
        try await Task.sleep(nanoseconds: 1_000_000_000)
    } catch {
        print("Cancelled the cancellable sleep")
    }
    print("ending outer cancellable")
})

//: [Next](@next)
