//
//  Channel.swift
//  
//
//  Created by Van Simmons on 1/28/22.
//
public func convertBuffering<In, Out>(
    _ input: AsyncStream<In>.Continuation.BufferingPolicy
) -> AsyncStream<Out>.Continuation.BufferingPolicy {
    switch input {
        case .unbounded:
            return .unbounded
        case .bufferingOldest(let value):
            return .bufferingOldest(value)
        case .bufferingNewest(let value):
            return .bufferingNewest(value)
        @unknown default:
            fatalError("Unhandled buffering policy case")
    }
}

public struct Channel<Element: Sendable>: AsyncSequence {
    let stream: AsyncStream<Element>
    let continuation: AsyncStream<Element>.Continuation

    init(
        stream: AsyncStream<Element>,
        continuation: AsyncStream<Element>.Continuation
    ) {
        self.stream = stream
        self.continuation = continuation
    }

    public init(
        _: Element.Type = Element.self,
        buffering: AsyncStream<Element>.Continuation.BufferingPolicy = .bufferingOldest(1)
    ) {
        var localContinuation: AsyncStream<Element>.Continuation!
        stream = .init(bufferingPolicy: buffering) { continuation in
            localContinuation = continuation
        }
        continuation = localContinuation
    }

    @discardableResult
    @Sendable public func yield(_ value: Element) -> AsyncStream<Element>.Continuation.YieldResult {
        continuation.yield(value)
    }
    @Sendable public func finish() -> Void {
        continuation.finish()
    }

    public __consuming func makeAsyncIterator() -> AsyncStream<Element>.Iterator {
        stream.makeAsyncIterator()
    }
}

public extension Channel where Element == Void {
    @discardableResult
    @Sendable func yield() -> AsyncStream<Element>.Continuation.YieldResult {
        continuation.yield(())
    }
}
