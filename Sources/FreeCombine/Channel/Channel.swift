//
//  Channel.swift
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

public extension Channel where Element == Void {
    @discardableResult
    @Sendable func yield() -> AsyncStream<Element>.Continuation.YieldResult {
        continuation.yield(())
    }
}

public extension Channel {
    func consume<Upstream>(
        publisher: Publisher<Upstream>
    ) async -> Cancellable<Demand> where Element == (AsyncStream<Upstream>.Result, UnsafeContinuation<Demand, Error>) {
        await consume(publisher: publisher, using: { ($0, $1) })
    }

    func consume<Upstream>(
        publisher: Publisher<Upstream>,
        using action: @escaping (AsyncStream<Upstream>.Result, UnsafeContinuation<Demand, Swift.Error>) -> Element
    ) async -> Cancellable<Demand>  {
        await publisher { upstreamValue in
            try await withUnsafeThrowingContinuation { continuation in
                switch self.yield(action(upstreamValue, continuation)) {
                    case .enqueued:
                        ()
                    case .dropped:
                        continuation.resume(throwing: PublisherError.enqueueError)
                    case .terminated:
                        continuation.resume(throwing: PublisherError.cancelled)
                    @unknown default:
                        fatalError("Unhandled continuation value")
                }
            }
        }
    }

    func stateTask<State>(
        initialState: @escaping (Self) async -> State,
        onCancel: @Sendable @escaping () -> Void = { },
        reducer: Reducer<State, Self.Element>
    ) async -> StateTask<State, Self.Element> {
        var stateTask: StateTask<State, Self.Element>!
        await withUnsafeContinuation { stateTaskContinuation in
            stateTask = .init(
                channel: self,
                initialState: initialState,
                onStartup: stateTaskContinuation,
                onCancel: onCancel,
                reducer: reducer
            )
        }
        return stateTask
    }
}
