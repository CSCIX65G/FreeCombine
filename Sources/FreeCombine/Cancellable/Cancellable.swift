//
//  Cancellable.swift
//  
//
//  Created by Van Simmons on 5/18/22.
//

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

    convenience init<Action: Sendable>(stateTask: StateTask<Output, Action>) {
        self.init(
            cancel: { stateTask.cancel() },
            isCancelled: { stateTask.isCancelled },
            value: { try await stateTask.value },
            result: { await stateTask.result }
        )
    }

    convenience init(task: @Sendable @escaping () async throws -> Output) {
        self.init(task: Task.init(operation: task))
    }
}
