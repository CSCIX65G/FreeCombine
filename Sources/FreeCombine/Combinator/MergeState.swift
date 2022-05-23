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
        case removeAll
    }

    let channel: Channel<MergeState<Output>.Action>
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
        self.channel = channel
        self.downstream = downstream
        self.mostRecentDemand = mostRecentDemand
        var localCancellables = [Int: Cancellable<Demand>]()
        let upstreams = ([upstream1, upstream2] + otherUpstreams)
            .enumerated()
            .map { (index: Int, publisher: Publisher<Output>) in
                publisher.map { value in (index, value) }
            }
        for (index, publisher) in upstreams.enumerated() {
            let c = await channel.consume(publisher: publisher, using: { result, continuation in
                if case AsyncStream<(Int, Output)>.Result.completion = result {
                    let queueStatus = channel.yield(.removeCancellable(index))
                    guard case .enqueued = queueStatus else {
                        fatalError("could not enqueue exit")
                    }
                }
                return MergeState<Output>.Action.setValue(result, continuation)
            })
            localCancellables[index] = c
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
        state.channel.yield(.removeAll)
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
                            await Task.yield()
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
                print("removing: \(index)")
                cancellables.removeValue(forKey: index)
                if cancellables.count == 0 {
                    print("finishing")
                    mostRecentDemand = try await downstream(.completion(.finished))
                    await Task.yield()
                    throw StateTaskError.completed
                }
            case .removeAll:
                cancellables.removeAll()
                mostRecentDemand = try await downstream(.completion(.finished))
                await Task.yield()
                throw StateTaskError.completed
        }
        await Task.yield()
    }
}
