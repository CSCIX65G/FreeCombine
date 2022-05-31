//
//  Cancellable.swift
//  
//
//  Created by Van Simmons on 5/18/22.
//

public final class Cancellable<Output: Sendable>: Sendable {
    public let cancel: @Sendable () -> Void
    private let _isCancelled: @Sendable () -> Bool
    private let _value: @Sendable () async throws -> Output
    private let _result: @Sendable () async -> Result<Output, Swift.Error>

    public var isCancelled: Bool {  _isCancelled() }
    public var value: Output {  get async throws { try await _value() } }
    public var result: Result<Output, Swift.Error> {  get async { await _result() } }

    public init(task: Task<Output, Swift.Error>) {
        self.cancel = { task.cancel() }
        self._isCancelled = { task.isCancelled }
        self._value = { try await task.value }
        self._result = { await task.result }
    }

    public init<Action: Sendable>(stateTask: StateTask<Output, Action>) {
        self.cancel = { stateTask.cancel() }
        self._isCancelled = { stateTask.isCancelled }
        self._value = { try await stateTask.value }
        self._result = { await stateTask.result }
    }

    public convenience init(task: @Sendable @escaping () async throws -> Output) {
        self.init(task: Task.init(operation: task))
    }

    deinit {
        if !self.isCancelled { self.cancel() }
    }
}
