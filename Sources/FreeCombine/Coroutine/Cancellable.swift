//
//  Cancellable.swift
//  
//
//  Created by Van Simmons on 1/28/22.
//

public struct Cancellable {
    @Sendable public static func noEffect() -> Void { }
    public static let empty: Cancellable = .init(noEffect)
    public let cancel: @Sendable () -> Void

    public init(_ cancel: @Sendable @escaping () -> Void) {
        self.cancel = cancel
    }

    public init<Value, E: Error>(_ task: Task<Value, E>) {
        self.cancel = { task.cancel() }
    }

    public func callAsFunction() -> Void {
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
