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
        case removeCancellable(Int, UnsafeContinuation<Demand, Swift.Error>)
    }

    let downstream: (AsyncStream<Output>.Result) async throws -> Demand

    var cancellables: [Int: Cancellable<Demand>]
    var mostRecentDemand: Demand

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
        var localCancellables = [Int: Cancellable<Demand>]()
        let upstreams = ([upstream1, upstream2] + otherUpstreams)
            .enumerated()
            .map { (index: Int, publisher: Publisher<Output>) in
                publisher.map { value in (index, value) }
            }
        for (index, publisher) in upstreams.enumerated() {
            localCancellables[index] = await channel.consume(publisher: publisher, using: { result, continuation in
                if case AsyncStream<(Int, Output)>.Result.completion = result {
                    return MergeState<Output>.Action.removeCancellable(index, continuation)
                }
                return MergeState<Output>.Action.setValue(result, continuation)
            })
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
        state.cancellables.values.forEach { cancellable in cancellable.cancel() }
        state.cancellables.removeAll()
    }

    static func reduce(
        `self`: inout Self,
        action: Self.Action
    ) async throws -> StateTask<Self, Action>.Effect {
        do {
            guard !Task.isCancelled else { throw StateTaskError.cancelled }
            return try await `self`.reduce(action: action)
        } catch {
            await complete(state: &`self`, completion: .cancel(`self`))
            throw error
        }
    }

    private mutating func reduce(
        action: Self.Action
    ) async throws -> StateTask<Self, Action>.Effect {
        switch action {
            case let .setValue(value, continuation):
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
                    case .completion(.finished):
                        fatalError("Should never get here.")
                }
            case let .removeCancellable(index, continuation):
                cancellables.removeValue(forKey: index)
                continuation.resume(returning: .done)
                if cancellables.count == 0 {
                    mostRecentDemand = try await downstream(.completion(.finished))
                    throw StateTaskError.completed
                }
        }
        return .none
    }
}
