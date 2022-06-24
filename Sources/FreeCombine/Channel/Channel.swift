//
//  Channel.swift
//  
//
//  Created by Van Simmons on 1/28/22.
//

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

public extension Channel {
    func consume<Upstream>(
        file: StaticString = #file,
        line: UInt = #line,
        deinitBehavior: DeinitBehavior = .assert,
        publisher: Publisher<Upstream>
    ) async -> Cancellable<Demand> where Element == (AsyncStream<Upstream>.Result, Resumption<Demand>) {
        await consume(file: file, line: line, deinitBehavior: deinitBehavior, publisher: publisher, using: { ($0, $1) })
    }

    func consume<Upstream>(
        file: StaticString = #file,
        line: UInt = #line,
        deinitBehavior: DeinitBehavior = .assert,
        publisher: Publisher<Upstream>,
        using action: @escaping (AsyncStream<Upstream>.Result, Resumption<Demand>) -> Element
    ) async -> Cancellable<Demand>  {
        await publisher { upstreamValue in
            try await withResumption(file: file, line: line, deinitBehavior: deinitBehavior) { resumption in
                if Task.isCancelled {
                    resumption.resume(throwing: PublisherError.cancelled)
                    return
                }
                switch self.yield(action(upstreamValue, resumption)) {
                    case .enqueued:
                        ()
                    case .dropped:
                        resumption.resume(throwing: PublisherError.enqueueError)
                    case .terminated:
                        resumption.resume(throwing: PublisherError.cancelled)
                    @unknown default:
                        fatalError("Unhandled continuation value")
                }
            }
        }
    }

    func stateTask<State>(
        file: StaticString = #file,
        line: UInt = #line,
        deinitBehavior: DeinitBehavior = .assert,
        initialState: @escaping (Self) async -> State,
        reducer: Reducer<State, Self.Element>
    ) async throws -> StateTask<State, Self.Element> {
        var stateTask: StateTask<State, Self.Element>!
        let _: Void = try await withResumption(file: file, line: line, deinitBehavior: deinitBehavior) { resumption in
            stateTask = .init(
                file: file,
                line: line,
                deinitBehavior: deinitBehavior,
                channel: self,
                initialState: initialState,
                onStartup: resumption,
                reducer: reducer
            )
        }
        return stateTask
    }

    func stateTask<State>(
        file: StaticString = #file,
        line: UInt = #line,
        deinitBehavior: DeinitBehavior = .assert,
        initialState: @escaping (Self) async -> State,
        onStartup: Resumption<Void>,
        reducer: Reducer<State, Self.Element>
    ) -> StateTask<State, Self.Element> {
        .init(
            file: file,
            line: line,
            deinitBehavior: deinitBehavior,
            channel: self,
            initialState: initialState,
            onStartup: onStartup,
            reducer: reducer
        )
    }
}
