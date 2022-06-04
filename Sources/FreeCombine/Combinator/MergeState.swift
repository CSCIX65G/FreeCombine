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
        case failure(Int, Error, UnsafeContinuation<Demand, Swift.Error>)
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
                switch result {
                    case .value:
                        return .setValue(result, continuation)
                    case .completion(.finished), .completion(.cancelled):
                        return .removeCancellable(index, continuation)
                    case let .completion(.failure(error)):
                        return .failure(index, error, continuation)
                }
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

    static func complete(state: inout Self, completion: Reducer<Self, Self.Action>.Completion) async -> Void {
        for cancellable in state.cancellables.values {
            cancellable.cancel()
            _ = await cancellable.result
        }
        state.cancellables.removeAll()
        guard state.mostRecentDemand != .done else { return }
        do {
            switch completion {
                case .termination:
                    state.mostRecentDemand = try await state.downstream(.completion(.finished))
                case .cancel:
                    state.mostRecentDemand = try await state.downstream(.completion(.cancelled))
                default:
                    () // These came from downstream and should not go again
            }
        } catch { }
    }

    static func reduce(
        `self`: inout Self,
        action: Self.Action
    ) async throws -> Reducer<Self, Action>.Effect {
        return try await `self`.reduce(action: action)
    }

    private mutating func reduce(
        action: Self.Action
    ) async throws -> Reducer<Self, Action>.Effect {
        guard !Task.isCancelled else { return .completion(.cancel) }
        switch action {
            case let .setValue(value, continuation):
                return try await reduceValue(value, continuation)
            case let .removeCancellable(index, continuation):
                cancellables.removeValue(forKey: index)
                continuation.resume(returning: .done)
                if cancellables.count == 0 {
                    let c: Completion = Task.isCancelled ? .cancelled : .finished
                    mostRecentDemand = try await downstream(.completion(c))
                    return .completion(.exit)
                }
                return .none
            case let .failure(index, error, continuation):
                cancellables.removeValue(forKey: index)
                continuation.resume(returning: .done)
                cancellables.removeAll()
                mostRecentDemand = try await downstream(.completion(.failure(error)))
                return .completion(.failure(error))
        }
    }

    private mutating func reduceValue(
        _ value: AsyncStream<(Int, Output)>.Result,
        _ continuation: UnsafeContinuation<Demand, Swift.Error>
    ) async throws -> Reducer<Self, Action>.Effect {
        switch value {
            case let .value((index, output)):
                guard let _ = cancellables[index] else {
                    fatalError("received value after task completion")
                }
                do {
                    mostRecentDemand = try await downstream(.value(output))
                    continuation.resume(returning: mostRecentDemand)
                    return .none
                }
                catch {
                    continuation.resume(throwing: error)
                    return .completion(.failure(error))
                }
            case let .completion(.failure(error)):
                continuation.resume(returning: .done)
                return .completion(.failure(error))
            case .completion(.finished):
                continuation.resume(returning: .done)
                return .none
            case .completion(.cancelled):
                continuation.resume(returning: .done)
                return .none
        }
    }
}
