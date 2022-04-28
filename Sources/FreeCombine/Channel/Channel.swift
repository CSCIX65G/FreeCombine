//
//  AwaitStream.swift
//  
//
//  Created by Van Simmons on 1/28/22.
//

public struct Channel<Element>: AsyncSequence {
    private let stream: AsyncStream<Element>
    private let continuation: AsyncStream<Element>.Continuation

    init(
        stream: AsyncStream<Element>,
        continuation: AsyncStream<Element>.Continuation
    ) {
        self.stream = stream
        self.continuation = continuation
    }

    public init(
        _: Element.Type = Element.self,
        buffering: AsyncStream<Element>.Continuation.BufferingPolicy = .bufferingOldest(1),
        onTermination: (@Sendable (AsyncStream<Element>.Continuation.Termination) -> Void)? = .none
    ) {
        var localContinuation: AsyncStream<Element>.Continuation! = .none
        stream = .init(bufferingPolicy: buffering) { continuation in
            localContinuation = continuation
            localContinuation.onTermination = onTermination
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

extension Channel where Element == Void {
    @discardableResult
    @Sendable public func yield() -> AsyncStream<Element>.Continuation.YieldResult {
        continuation.yield(())
    }
}
