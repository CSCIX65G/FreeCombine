//
//  MergeState.swift
//  
//
//  Created by Van Simmons on 5/19/22.
//
struct MergeState<Output: Sendable>: CombinatorState {
    typealias CombinatorAction = Self.Action
    enum Action {
        case setValue(AsyncStream<(Int, Output)>.Result, UnsafeContinuation<Demand, Swift.Error>)
        case removeCancellable(Int)
    }

    let downstream: (AsyncStream<Output>.Result) async throws -> Demand

    var cancellables: [Int: Task<Demand, Swift.Error>]
    var mostRecentDemand: Demand
    var currentContinuation: UnsafeContinuation<Demand, Swift.Error>?

    init(
        channel: Channel<MergeState<Output>.Action>,
        downstream: @escaping (AsyncStream<(Output)>.Result) async throws -> Demand,
        mostRecentDemand: Demand = .more,
        upstreams upstream1: Publisher<Output>,
        _ upstream2: Publisher<Output>,
        _ otherUpstreams: Publisher<Output>...
    ) async {
        await self.init(
            channel: channel,
            downstream: downstream,
            upstreams: upstream1, upstream2, otherUpstreams
        )
    }

    init(
        channel: Channel<MergeState<Output>.Action>,
        downstream: @escaping (AsyncStream<(Output)>.Result) async throws -> Demand,
        mostRecentDemand: Demand = .more,
        upstreams upstream1: Publisher<Output>,
        _ upstream2: Publisher<Output>,
        _ otherUpstreams: [Publisher<Output>]
    ) async {
        self.downstream = downstream
        self.mostRecentDemand = mostRecentDemand
        var localCancellables = [Int: Task<Demand, Swift.Error>]()
        let upstreams = ([upstream1, upstream2] + otherUpstreams)
            .enumerated()
            .map { (index: Int, publisher: Publisher<Output>) in
                publisher.map { value in (index, value) }
            }
        for (index, publisher) in upstreams.enumerated() {
            localCancellables[index] = Task {
                let r = await channel.consume(publisher: publisher, using: MergeState<Output>.Action.setValue).result
                channel.yield(.removeCancellable(index))
                switch r {
                    case .success(let value): return value
                    case .failure(let error): throw error
                }
            }
        }
        cancellables = localCancellables
    }

    static func create(
        mostRecentDemand: Demand = .more,
        upstreams upstream1: Publisher<Output>,
        _ upstream2: Publisher<Output>,
        _ otherUpstreams: [Publisher<Output>]
    ) -> (@escaping (AsyncStream<Output>.Result) async throws -> Demand) -> (Channel<MergeState<Output>.Action>) async -> Self {
        { downstream in { channel in
            await .init(channel: channel, downstream: downstream, upstreams: upstream1, upstream2, otherUpstreams)
        } }
    }

    static func complete(state: inout Self, completion: StateTask<Self, Self.Action>.Completion) async -> Void {
        for (_, task) in state.cancellables {
            switch completion {
                case let .cancel(state):
                    state.currentContinuation?.resume(throwing: PublisherError.cancelled)
                case .termination, .exit:
                    state.currentContinuation?.resume(returning: .done)
                case let .failure(error):
                    state.currentContinuation?.resume(throwing: error)
            }
            task.cancel()
            _ = await task.result
        }
        state.removeAll()
    }

    static func reduce(`self`: inout Self, action: Self.Action) async throws -> Void {
        do {
            guard !Task.isCancelled else { throw StateTaskError.cancelled }
            try await `self`.reduce(action: action)
        } catch {
            await complete(state: &`self`, completion: .cancel(`self`))
            throw error
        }
    }

    private mutating func reduce(
        action: Self.Action
    ) async throws -> Void {
        switch action {
            case let .setValue(value, continuation):
                currentContinuation = continuation
                switch value {
                    case let .value((index, output)):
                        guard let _ = cancellables[index] else {
                            fatalError("received value after task completion")
                        }
                        do {
                            mostRecentDemand = try await downstream(.value(output))
                            continuation.resume(returning: mostRecentDemand)
                        }
                        catch {
                            continuation.resume(throwing: error)
                            throw error
                        }
                    case let .completion(.failure(error)):
                        do {
                            mostRecentDemand = try await downstream(.completion(.failure(error)))
                            continuation.resume(returning: mostRecentDemand)
                        }
                        catch {
                            continuation.resume(throwing: error)
                        }
                        return
                    case .completion(.finished):
                        continuation.resume(returning: .done)
                }
            case let .removeCancellable(index):
                cancellables.removeValue(forKey: index)
                if cancellables.count == 0 {
                    mostRecentDemand = try await downstream(.completion(.finished))
                    throw StateTaskError.completed
                }
        }
    }

    private mutating func removeAll() -> Void {
        cancellables.removeAll()
    }
}
