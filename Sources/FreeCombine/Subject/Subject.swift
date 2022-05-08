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

//fileprivate struct ZipState<Left: Sendable, Right: Sendable>: CombinatorState {
//    typealias CombinatorAction = Self.Action
//    enum Action {
//        case setLeft(AsyncStream<Left>.Result, UnsafeContinuation<Demand, Swift.Error>)
//        case setRight(AsyncStream<Right>.Result, UnsafeContinuation<Demand, Swift.Error>)
//    }
//    let downstream: (AsyncStream<(Left, Right)>.Result) async throws -> Demand


public final class Subject<Output: Sendable> {
    enum Completion {
        case finished
        case failure(Error)
    }

    struct DownstreamState {
        enum Action: Sendable {
            case send(
                result: AsyncStream<Output>.Result,
                semaphore: Semaphore<[Int], DistributorAction<Int>>,
                completion: @Sendable (Completion) -> () -> Void
            )
        }
        let downstream: (AsyncStream<Output>.Result) async throws -> Demand
    }
    
    fileprivate struct State {
        var currentValue: Output
        var nextKey: Int
        var downstreams: [Int: StateTask<DownstreamState, DownstreamState.Action>]
    }

    enum Action: Sendable {
        case send(AsyncStream<Output>.Result, UnsafeContinuation<Void, Swift.Error>?)
        case subscribe(
            @Sendable (AsyncStream<Output>.Result) async throws -> Demand,
            UnsafeContinuation<Task<Demand, Swift.Error>, Swift.Error>?
        )
        case unsubscribe(Int, UnsafeContinuation<Void, Swift.Error>?)
    }
    private let stateTask: StateTask<Subject<Output>.State, Subject<Output>.Action>

    init(
        currentValue: Output,
        buffering: AsyncStream<Subject<Output>.Action>.Continuation.BufferingPolicy = .bufferingOldest(1),
        onStartup: UnsafeContinuation<Void, Never>? = .none
    ) {
        self.stateTask = .init(
            initialState: { channel in .init(currentValue: currentValue, nextKey: 0, downstreams: [:]) },
            buffering: buffering,
            onStartup: onStartup,
            reducer: subjectReducer
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
