//
//  File.swift
//  
//
//  Created by Van Simmons on 4/17/22.
//

public struct Distibutor<Output: Sendable> {
    struct DownstreamState { }
    enum DownstreamAction: Sendable {
        case send(
            result: AsyncStream<Output>.Result,
            semaphore: EffectfulSemaphore,
            onError: @Sendable (Swift.Error) -> () -> Void,
            onFinish: @Sendable () -> Void
        )
    }

    fileprivate struct State {
        var nextKey: Int
        var downstreams: [Int: StateThread<DownstreamState, DownstreamAction>]
    }

    fileprivate enum Action: Sendable {
        case send(AsyncStream<Output>.Result, UnsafeContinuation<Void, Swift.Error>?)
        case subscribe(
            @Sendable (AsyncStream<Output>.Result) async throws -> Demand,
            UnsafeContinuation<Task<Output, Swift.Error>, Swift.Error>?
        )
        case unsubscribe(Int, UnsafeContinuation<Void, Swift.Error>?)
    }
    private let stateThread: StateThread<Distibutor<Output>.State, Distibutor<Output>.Action>
}
