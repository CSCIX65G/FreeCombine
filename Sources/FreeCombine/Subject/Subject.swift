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
    enum Completion {
        case finished
        case failure(Error)
    }

    struct DownstreamState { }
    fileprivate enum DownstreamAction: Sendable {
        case send(
            result: AsyncStream<Output>.Result,
            semaphore: EffectfulSemaphore,
            completion: @Sendable (Completion) -> () -> Void
        )
    }

    fileprivate struct State {
        var currentValue: Output
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
            initialState: { channel in .init(currentValue: currentValue, nextKey: 0, downstreams: [:]) },
            buffering: buffering,
            onStartup: onStartup,
            operation: subjectReducer
        )
    }
}

extension Subject {
    func reduce(
        action: Action
    ) async throws -> Void {
//        switch action {
//            case let .send(result, continuation):
//                return
//            case let .subscribe(downstream, continuation):
//                return
//            case let .unsubscribe(channelId, continuation):
//                return
//        }
    }

    static func reduce(`self`: inout Subject, action: Action) async throws -> Void {
        try await `self`.reduce(action: action)
    }
}
