//
//  DistributorState.swift
//  
//
//  Created by Van Simmons on 5/10/22.
//
//  Copyright 2022, ComputeCycles, LLC
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//
public struct DistributorState<Output: Sendable> {
    public typealias Downstream = @Sendable (AsyncStream<Output>.Result) async throws -> Demand
    public private(set) var currentValue: Output?
    var nextKey: Int
    var repeaters: [Int: StateTask<DistributorRepeaterState<Int, Output>, DistributorRepeaterState<Int, Output>.Action>]
    var isComplete = false

    public enum Error: Swift.Error {
        case alreadyCompleted
    }

    public enum Action: Sendable {
        case receive(AsyncStream<Output>.Result, Resumption<Int>)
        case subscribe(Downstream, Resumption<Cancellable<Demand>>)
        case unsubscribe(Int)
    }

    public init(
        currentValue: Output?,
        nextKey: Int,
        downstreams: [Int: StateTask<DistributorRepeaterState<Int, Output>, DistributorRepeaterState<Int, Output>.Action>]
    ) {
        self.currentValue = currentValue
        self.nextKey = nextKey
        self.repeaters = downstreams
    }

    static func create(
    ) -> (Channel<DistributorState<Output>.Action>) -> Self {
        { channel in .init(currentValue: .none, nextKey: 0, downstreams: [:]) }
    }

    static func complete(state: inout Self, completion: Reducer<Self, Self.Action>.Completion) async -> Void {
        switch completion {
            case .finished, .exit:
                try! await state.process(currentRepeaters: state.repeaters, with: .completion(.finished))
            case let .failure(error):
                try! await state.process(currentRepeaters: state.repeaters, with: .completion(.failure(error)))
            case .cancel:
                try! await state.process(currentRepeaters: state.repeaters, with: .completion(.cancelled))
        }
        for (_, repeater) in state.repeaters {
            repeater.finish()
        }
        state.repeaters.removeAll()
    }

    static func dispose(action: Self.Action, completion: Reducer<Self, Self.Action>.Completion) async -> Void {
        switch action {
            case let .receive(_, resumption):
                resumption.resume(throwing: PublisherError.cancelled)
            case let .subscribe(downstream, resumption):
                switch completion {
                    case .failure(PublisherError.completed):
                        let _ = try? await downstream(.completion(.finished))
                        resumption.resume(throwing: PublisherError.completed)
                    case .failure(PublisherError.cancelled):
                        let _ = try? await downstream(.completion(.cancelled))
                        resumption.resume(throwing: PublisherError.cancelled)
                    case let .failure(error):
                        let _ = try? await downstream(.completion(.failure(error)))
                        resumption.resume(throwing: error)
                    default:
                        let _ = try? await downstream(.completion(.finished))
                        resumption.resume(returning: .init { return .done })
                }
            case .unsubscribe:
                ()
        }
    }

    static func reduce(`self`: inout Self, action: Self.Action) async throws -> Reducer<Self, Action>.Effect {
        if Task.isCancelled {
            switch action {
                case .receive(_, let resumption):
                    resumption.resume(throwing: PublisherError.cancelled)
                case .subscribe(_, let resumption):
                    resumption.resume(throwing: PublisherError.cancelled)
                case .unsubscribe(_):
                    ()
            }
            return .completion(.cancel)
        }
        return try await `self`.reduce(action: action)
    }

    mutating func reduce(action: Action) async throws -> Reducer<Self, Action>.Effect {
        switch action {
            case let .receive(result, resumption):
                if case let .value(newValue) = result, currentValue != nil { currentValue = newValue }
                if case .completion = result { isComplete = true }
                do {
                    let repeaterCount = repeaters.count
                    try await process(currentRepeaters: repeaters, with: result)
                    resumption.resume(returning: repeaterCount)
                } catch {
                    resumption.resume(throwing: error)
                    throw error
                }
                return isComplete
                    ? .completion(.exit)
                    : .none
            case let .subscribe(downstream, resumption):
                var repeater: Cancellable<Demand>!
                if isComplete {
                    resumption.resume(returning: .init { try await downstream(.completion(.finished)) } )
                    return .completion(.exit)
                }
                let _: Void = try await withResumption { outerResumption in
                    repeater = process(subscription: downstream, resumption: outerResumption)
                }
                if let currentValue = currentValue, try await downstream(.value(currentValue)) == .done {
                    // FIXME: handle first value cancellation
                }
                resumption.resume(returning: repeater)
                return .none
            case let .unsubscribe(channelId):
                guard let downstream = repeaters.removeValue(forKey: channelId) else {
                    return .none
                }
                try await process(currentRepeaters: [channelId: downstream], with: .completion(.finished))
                return .none
        }
    }

    mutating func process(
        currentRepeaters : [Int: StateTask<DistributorRepeaterState<Int, Output>, DistributorRepeaterState<Int, Output>.Action>],
        with result: AsyncStream<Output>.Result
    ) async throws -> Void {
        guard currentRepeaters.count > 0 else { return }
        try await withResumption { (completedResumption: Resumption<[Int]>) in
            // Note that the semaphore's reducer constructs a list of repeaters
            // which have responded with .done and that the elements of that list
            // are removed at completion of the sends
            let semaphore = Semaphore<[Int], RepeatedAction<Int>>(
                resumption: completedResumption,
                reducer: { completedIds, action in
                    guard case let .repeated(id, .done) = action else { return }
                    completedIds.append(id)
                },
                initialState: [Int](),
                count: currentRepeaters.count
            )

            currentRepeaters.forEach { key, downstreamTask in
                let queueStatus = downstreamTask.send(.repeat(result, semaphore))
                switch queueStatus {
                    case .enqueued:
                        ()
                    case .terminated:
                        Task { await semaphore.decrement(with: .repeated(key, .done)) }
                    case .dropped:
                        fatalError("Should never drop")
                    @unknown default:
                        fatalError("Handle new case")
                }
            }
        }
        .forEach { key in
            repeaters.removeValue(forKey: key)
        }
    }

    mutating func process(
        subscription downstream: @escaping @Sendable (AsyncStream<Output>.Result) async throws -> Demand,
        resumption: Resumption<Void>
    ) -> Cancellable<Demand> {
        nextKey += 1
        let repeaterState = DistributorRepeaterState(id: nextKey, downstream: downstream)
        let repeater: StateTask<DistributorRepeaterState<Int, Output>, DistributorRepeaterState<Int, Output>.Action> = .init(
            channel: .init(buffering: .bufferingOldest(1)),
            onStartup: resumption,
            initialState: { _ in repeaterState },
            reducer: Reducer(
                reducer: DistributorRepeaterState.reduce,
                finalizer: DistributorRepeaterState.complete
            )
        )
        repeaters[nextKey] = repeater
        return .init {
            try await withTaskCancellationHandler(
                operation: {
                    try await repeater.value.mostRecentDemand
                },
                onCancel: repeater.cancel
            )
        }
    }
}
