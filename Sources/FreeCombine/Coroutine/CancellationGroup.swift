//
//  CancellationGroup.swift
//  
//
//  Created by Van Simmons on 2/4/22.
//

public enum CancellationError: Error {
    case cancel
}

public actor CancellationGroup {
    public private(set) var isCancelled: Bool = false
    public private(set) var cancellables: [Cancellable] = []

    public init(cancellables: Cancellable...) {
        self.cancellables = cancellables
    }

    deinit {
        cancel()
    }

    public func add(_ cancellable: Cancellable) -> Void {
        guard !isCancelled else { return }
        var cancellables = self.cancellables
        cancellables.append(cancellable)
        self.cancellables = cancellables
    }

    public func add<Value, E: Error>(_ task: Task<Value, E>) -> Void {
        guard !isCancelled else { return }
        var cancellables = self.cancellables
        cancellables.append(.init { task.cancel() })
        self.cancellables = cancellables
    }

    public func add<Value, E: Error>(_ tasks: Task<Value, E>...) -> Void {
        guard !isCancelled else { return }
        var cancellables = self.cancellables
        cancellables += tasks.map(Cancellable.init)
        self.cancellables = cancellables
    }

    public func add(_ newCancellables: Cancellable...) -> Void {
        guard !isCancelled else { return }
        var cancellables = self.cancellables
        cancellables += newCancellables
        self.cancellables = cancellables
    }

    public func push(_ newCancellable: Cancellable) -> Void {
        guard !isCancelled else { return }
        var cancellables = self.cancellables
        cancellables.append(newCancellable)
        self.cancellables = cancellables
    }

    @discardableResult
    public func pop() -> Cancellable? {
        guard !isCancelled else { return .none }
        var cancellables = self.cancellables
        guard cancellables.count > 0 else { return .none }
        let c = cancellables.removeLast()
        self.cancellables = cancellables
        return c
    }

    public func cancel() -> Void {
        isCancelled = true
        let cancellables = self.cancellables
        self.cancellables = []
        cancellables.forEach { cancellable in cancellable.cancel() }
        return
    }

    @Sendable public nonisolated func nonIsolatedCancel() -> Void {
        Task {
            guard await !self.isCancelled else { return }
            let tasks = await self.cancellables
            await cancel()
            tasks.forEach { task in task.cancel() }
            return
        }
    }
}

