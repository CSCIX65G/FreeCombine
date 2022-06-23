//
//  LazyValueRef.swift
//  
//
//  Created by Van Simmons on 6/10/22.
//
public struct LazyValueRefState<Value: Sendable> {
    public enum Error: Swift.Error {
        case deallocated
        case finished
        case dropped
    }
    public enum Action: Sendable {
        case value(Resumption<Value>)
        case retain(Resumption<Void>)
        case release(Resumption<Void>)
    }
    var value: Value?
    var refCount: Int = 0
    var creator: (() async throws -> Value)?
    var disposer: (Value) async -> Void

    public init(
        creator: @escaping () async throws -> Value,
        disposer: @escaping (Value) async -> Void = {_ in }
    ) async {
        self.creator = creator
        self.disposer = disposer
    }

    static func complete(state: inout Self, completion: Reducer<Self, Self.Action>.Completion) async -> Void {
        if let value = state.value {
            await state.disposer(value)
        }
        state.value = .none
        state.creator = .none
        state.refCount = 0
    }

    static func dispose(action: Self.Action, completion: Reducer<Self, Self.Action>.Completion) -> Void {
        switch action {
            case let .value(continuation): continuation.resume(throwing: Error.deallocated)
            case let .retain(continuation): continuation.resume(throwing: Error.deallocated)
            case let .release(continuation): continuation.resume(throwing: Error.deallocated)
        }
    }

    static func reduce(`self`: inout Self, action: Self.Action) async throws -> Reducer<Self, Action>.Effect {
        guard !Task.isCancelled else { return .completion(.cancel) }
        return try await `self`.reduce(action: action)
    }

    private mutating func reduce(
        action: Self.Action
    ) async throws -> Reducer<Self, Action>.Effect {
        switch action {
            case let .value(resumption):
                guard let value = value else {
                    guard let creator = creator else {
                        resumption.resume(throwing: Error.deallocated)
                        return .completion(.failure(Error.deallocated))
                    }
                    do {
                        value = try await creator()
                        self.creator = .none
                        refCount += 1
                        resumption.resume(returning: value!)
                        return .none
                    }
                }
                refCount += 1
                resumption.resume(returning: value)
                return .none
            case let .retain(continuation):
                guard let _ = value else {
                    continuation.resume(throwing: Error.deallocated)
                    return .completion(.failure(Error.deallocated))
                }
                refCount += 1
                continuation.resume()
                return .none
            case let .release(continuation):
                guard let _ = value else {
                    continuation.resume(throwing: Error.deallocated)
                    return .completion(.failure(Error.deallocated))
                }
                refCount -= 1
                continuation.resume()
                return refCount == 0 ? .completion(.exit) : .none
        }
    }
}

public extension StateTask {
    static func stateTask<Value>(
        file: StaticString = #file,
        line: UInt = #line,
        deinitBehavior: DeinitBehavior = .assert,
        creator: @escaping () async throws -> Value,
        disposer: @escaping (Value) async -> Void
    ) async -> StateTask where State == LazyValueRefState<Value>, Action == LazyValueRefState<Value>.Action  {
        try! await Channel<LazyValueRefState<Value>.Action>.init(buffering: .unbounded)
            .stateTask(
                file: file,
                line: line,
                deinitBehavior: deinitBehavior,
                initialState: { _ in await .init(creator: creator, disposer: disposer) },
                reducer: .init(
                    onCompletion: LazyValueRefState<Value>.complete,
                    disposer: LazyValueRefState<Value>.dispose,
                    reducer: LazyValueRefState<Value>.reduce
                )
            )
    }
}

public func LazyValueRef<Value>(
    file: StaticString = #file,
    line: UInt = #line,
    deinitBehavior: DeinitBehavior = .assert,
    creator: @escaping () async throws -> Value,
    disposer: @escaping (Value) async -> Void
) async -> StateTask<LazyValueRefState<Value>, LazyValueRefState<Value>.Action> {
    await .stateTask(
        file: file,
        line: line,
        deinitBehavior: deinitBehavior,
        creator: creator,
        disposer: disposer
    )
}

public extension StateTask {
    func value<Value>() async throws -> Value? where State == LazyValueRefState<Value>, Action == LazyValueRefState<Value>.Action {
        let value: Value = try await withResumption({ resumption in
            let queueStatus = self.channel.yield(.value(resumption))
            switch queueStatus {
                case .enqueued:
                    ()
                case .terminated:
                    resumption.resume(throwing: LazyValueRefState<Value>.Error.finished)
                case .dropped:
                    resumption.resume(throwing: LazyValueRefState<Value>.Error.dropped)
                @unknown default:
                    fatalError("Handle new case")
            }
        })
        return value
    }
    func retain<Value>() async throws -> Void where State == LazyValueRefState<Value>, Action == LazyValueRefState<Value>.Action {
        let _: Void = try await withResumption({ continuation in
            let queueStatus = self.channel.yield(.retain(continuation))
            switch queueStatus {
                case .enqueued:
                    ()
                case .terminated:
                    continuation.resume(throwing: LazyValueRefState<Value>.Error.finished)
                case .dropped:
                    continuation.resume(throwing: LazyValueRefState<Value>.Error.dropped)
                @unknown default:
                    fatalError("Handle new case")
            }
        })
    }
    func release<Value>() async throws -> Void where State == LazyValueRefState<Value>, Action == LazyValueRefState<Value>.Action {
        let _: Void = try await withResumption({ resumption in
            let queueStatus = self.channel.yield(.release(resumption))
            switch queueStatus {
                case .enqueued:
                    ()
                case .terminated:
                    resumption.resume(throwing: LazyValueRefState<Value>.Error.finished)
                case .dropped:
                    resumption.resume(throwing: LazyValueRefState<Value>.Error.dropped)
                @unknown default:
                    fatalError("Handle new case")
            }
        })
        return
    }
}
