//
//  Subject.swift
//  
//
//  Created by Van Simmons on 3/22/22.
//

fileprivate func subjectReducer<Output: Sendable>(
    state: inout Subject<Output>.State,
    action: Subject<Output>.Action
) async throws -> Void {

}

public final class Subject<Output: Sendable> {
    struct DownstreamState { }
    fileprivate enum DownstreamAction: Sendable {
        case send(
            result: AsyncStream<Output>.Result,
            semaphore: EffectfulSemaphore,
            onError: @Sendable (Swift.Error) -> () -> Void,
            onFinish: @Sendable () -> Void
        )
    }

    fileprivate struct State {
        var currentValue: Output?
        var nextKey: Int
        var downstreams: [Int: StateThread<DownstreamState, DownstreamAction>]
    }

    enum Action: Sendable {
        case send(AsyncStream<Output>.Result, UnsafeContinuation<Void, Swift.Error>?)
        case subscribe(
            @Sendable (AsyncStream<Output>.Result) async throws -> Demand,
            UnsafeContinuation<Task<Demand, Swift.Error>, Swift.Error>?
        )
        case unsubscribe(Int, UnsafeContinuation<Void, Swift.Error>?)
    }
    private let stateThread: StateThread<Subject<Output>.State, Subject<Output>.Action>

    init(
        currentValue: Output,
        buffering: AsyncStream<Subject<Output>.Action>.Continuation.BufferingPolicy = .bufferingOldest(1),
        onStartup: UnsafeContinuation<Void, Never>? = .none
    ) {
        self.stateThread = .init(
            initialState: .init(currentValue: currentValue, nextKey: 0, downstreams: [:]),
            buffering: buffering,
            onStartup: onStartup,
            eventHandler: .init(),
            operation: subjectReducer
        )
    }
}
