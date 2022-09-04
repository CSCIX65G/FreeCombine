//
//  PromiseState.swift
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
public struct PromiseState<Output: Sendable> {
    public typealias Downstream = @Sendable (Result<Output, Swift.Error>) async throws -> Void
    public private(set) var currentValue: Output?
    var nextKey: Int
    var repeaters: [Int: StateTask<PromiseRepeaterState<Int, Output>, PromiseRepeaterState<Int, Output>.Action>]
    var isComplete = false

    public let function: StaticString
    public let file: StaticString
    public let line: UInt

    public enum Error: Swift.Error {
        case alreadyCompleted
    }

    public enum Action: Sendable {
        case receive(Result<Output, Swift.Error>, Resumption<Int>)
        case subscribe(Downstream, Resumption<Cancellable<Void>>)
        case unsubscribe(Int)
    }

    public init(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line,
        currentValue: Output?,
        nextKey: Int,
        downstreams: [Int: StateTask<PromiseRepeaterState<Int, Output>, PromiseRepeaterState<Int, Output>.Action>]
    ) {
        self.function = function
        self.file = file
        self.line = line
        self.currentValue = currentValue
        self.nextKey = nextKey
        self.repeaters = downstreams
    }

    static func create(
    ) -> (Channel<PromiseState<Output>.Action>) -> Self {
        { channel in .init(currentValue: .none, nextKey: 0, downstreams: [:]) }
    }

    static func complete(state: inout Self, completion: Reducer<Self, Self.Action>.Completion) async -> Void {
        switch completion {
            case .finished, .exit:
                assert(
                    state.repeaters.count == 0,
                    "ABORTING DUE TO NON-EMPTY REPEATERS \(state.repeaters.count)) STILL PRESENT"
                )
            case let .failure(error):
                try! await state.process(currentRepeaters: state.repeaters, with: .failure(error))
            case .cancel:
                try! await state.process(
                    currentRepeaters: state.repeaters,
                    with: .failure(PublisherError.cancelled)
                )
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
                    case let .failure(error):
                        let _ = try? await downstream(.failure(error))
                        resumption.resume(throwing: error)
                    default:
                        let _ = try? await downstream(.failure(PublisherError.completed))
                        resumption.resume(throwing: PublisherError.cancelled)
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
                if case let .success(newValue) = result, currentValue != nil { currentValue = newValue }
                if case .success = result { isComplete = true }
                do {
                    let repeaterCount = repeaters.count
                    try await process(currentRepeaters: repeaters, with: result)
                    resumption.resume(returning: repeaterCount)
                } catch {
                    resumption.resume(throwing: error)
                    throw error
                }
                return .completion(.exit)
            case let .subscribe(downstream, resumption):
                var repeater: Cancellable<Void>!
                if let currentValue = currentValue {
                    resumption.resume(returning: .init { try await downstream(.success(currentValue)) } )
                    return .completion(.exit)
                } else if isComplete {
                    resumption.resume(returning: .init { try await downstream(.failure(PublisherError.cancelled)) } )
                    return .completion(.exit)
                }
                let _: Void = try await withResumption { outerResumption in
                    repeater = process(subscription: downstream, resumption: outerResumption)
                }
                resumption.resume(returning: repeater)
                return .none
            case let .unsubscribe(channelId):
                guard let downstream = repeaters.removeValue(forKey: channelId) else {
                    return .none
                }
                try await process(currentRepeaters: [channelId: downstream], with: .failure(PublisherError.cancelled))
                return .none
        }
    }

    mutating func process(
        currentRepeaters : [Int: StateTask<PromiseRepeaterState<Int, Output>, PromiseRepeaterState<Int, Output>.Action>],
        with result: Result<Output, Swift.Error>
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
                let queueStatus = downstreamTask.send(.complete(result, semaphore))
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
        .forEach {
            repeaters.removeValue(forKey: $0)
        }
    }

    mutating func process(
        subscription downstream: @escaping @Sendable (Result<Output, Swift.Error>) async throws -> Void,
        resumption: Resumption<Void>
    ) -> Cancellable<Void> {
        nextKey += 1
        let repeaterState = PromiseRepeaterState(id: nextKey, downstream: downstream)
        let repeater: StateTask<PromiseRepeaterState<Int, Output>, PromiseRepeaterState<Int, Output>.Action> = .init(
            channel: .init(buffering: .bufferingOldest(1)),
            onStartup: resumption,
            initialState: { _ in repeaterState },
            reducer: Reducer(
                reducer: PromiseRepeaterState.reduce,
                finalizer: PromiseRepeaterState.complete
            )
        )
        repeaters[nextKey] = repeater
        return .init { _ = try await repeater.value; return }
    }
}

