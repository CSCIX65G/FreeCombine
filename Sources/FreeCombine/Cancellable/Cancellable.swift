//
//  Cancellable.swift
//  
//
//  Created by Van Simmons on 5/18/22.
//

public final class Cancellable<Output: Sendable>: Sendable {
    public let task: Task<Output, Swift.Error>

    public init(task: Task<Output, Swift.Error>) {
        self.task = task
    }

    public init(task: @Sendable @escaping () async throws -> Output) {
        self.task = Task.init(operation: task)
    }

    public func cancel() {
        task.cancel()
    }

    deinit {
        if !self.task.isCancelled {
            self.task.cancel()
        }
    }
}
