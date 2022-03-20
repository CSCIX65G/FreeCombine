//
//  CancellationGroup.swift
//  
//
//  Created by Van Simmons on 2/4/22.
//

public enum CancellationError: Error {
    case cancel
    case alreadyCancelled
}

fileprivate struct Cancellable {
    @Sendable public static func noEffect() -> Void { }
    public static let empty: Cancellable = .init(noEffect)
    public let cancel: @Sendable () -> Void

    @Sendable public init(_ cancel: @Sendable @escaping () -> Void) {
        self.cancel = cancel
    }

    @Sendable public init<Value, E: Error>(_ task: Task<Value, E>) {
        self.cancel = { task.cancel() }
    }

    @Sendable public func callAsFunction() -> Void {
        guard !Task.isCancelled else { return }
        cancel()
    }
    public func map(_ next: @Sendable @escaping () -> Void) -> Cancellable {
        .init {
            self.cancel()
            next()
        }
    }
    public func zip(_ other: Cancellable) -> Cancellable {
        .init {
            self.cancel()
            other.cancel()
        }
    }
    public func flatMap(_ next: @Sendable @escaping () -> Cancellable) -> Cancellable {
        .init {
            self.cancel()
            next().cancel()
        }
    }
}

public actor CancellationGroup {
    public private(set) var isCancelled: Bool = false
    private var cancellables: [Cancellable] = []

    public init() {
        self.cancellables = []
    }

    public init(onCancel: @Sendable @escaping () -> Void) {
        self.cancellables = [.init(onCancel)]
    }

    private init(cancellables: Cancellable...) {
        self.cancellables = cancellables
    }

    deinit {
        try? cancel()
    }

    private func add(_ cancellable: Cancellable) -> Void {
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

    public func add(_ newCancellables: @Sendable () -> Void...) -> Void {
        guard !isCancelled else { return }
        var cancellables = self.cancellables
        cancellables += newCancellables.map(Cancellable.init)
        self.cancellables = cancellables
    }

    private func add(_ newCancellables: Cancellable...) -> Void {
        guard !isCancelled else { return }
        var cancellables = self.cancellables
        cancellables += newCancellables
        self.cancellables = cancellables
    }

    public func push(_ newCancellable: @Sendable @escaping () -> Void) -> Void {
        guard !isCancelled else { return }
        var cancellables = self.cancellables
        cancellables.append(.init(newCancellable))
        self.cancellables = cancellables
    }

    private func push(_ newCancellable: Cancellable) -> Void {
        guard !isCancelled else { return }
        var cancellables = self.cancellables
        cancellables.append(newCancellable)
        self.cancellables = cancellables
    }

    @discardableResult
    public func pop() -> (@Sendable () -> Void)? {
        guard !isCancelled else { return .none }
        var cancellables = self.cancellables
        guard cancellables.count > 0 else { return .none }
        let c = cancellables.removeLast()
        self.cancellables = cancellables
        return c.cancel
    }

    @discardableResult
    private func pop() -> Cancellable? {
        guard !isCancelled else { return .none }
        var cancellables = self.cancellables
        guard cancellables.count > 0 else { return .none }
        let c = cancellables.removeLast()
        self.cancellables = cancellables
        return c
    }

    public func cancel() throws -> Void {
        guard !isCancelled else { throw CancellationError.alreadyCancelled }
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
            try await cancel()
            tasks.forEach { task in task.cancel() }
            return
        }
    }
}

