//
//  Autoconnect.swift
//  
//
//  Created by Van Simmons on 6/7/22.
//
public func convertBuffering<In, Out>(
    _ input: AsyncStream<In>.Continuation.BufferingPolicy
) -> AsyncStream<Out>.Continuation.BufferingPolicy {
    switch input {
        case .unbounded:
            return .unbounded
        case .bufferingOldest(let value):
            return .bufferingOldest(value)
        case .bufferingNewest(let value):
            return .bufferingNewest(value)
        @unknown default:
            fatalError("Unhandled buffering policy case")
    }
}

public extension Publisher {
    func autoconnect(
        buffering: AsyncStream<ConnectableState<Output>.Action>.Continuation.BufferingPolicy = .bufferingOldest(1)
    ) async -> Self {
        let mActor: ValueRef<ConnectableTask?>? = .init(value: .none)
        let multicaster = await LazyValueRef(
            creator: {  await Connectable<Output>.init(
                stateTask: try Channel.init(buffering: buffering)
                    .stateTask(
                        initialState: ConnectableState<Output>.create(upstream: self),
                        reducer: Reducer(
                            onCompletion: ConnectableState<Output>.complete,
                            disposer: ConnectableState<Output>.dispose,
                            reducer: ConnectableState<Output>.reduce
                        )
                    )
            ) },
            disposer: { value in
                _ = await mActor?.value?.finishAndAwaitResult()
            }
        )
        await mActor?.set(value: multicaster)
        return .init { continuation, downstream in
            Cancellable<Cancellable<Demand>>.join(.init {
                @Sendable func lift(
                    _ downstream: @Sendable @escaping (AsyncStream<Output>.Result) async throws -> Demand
                ) -> @Sendable (AsyncStream<Output>.Result) async throws -> Demand {
                    { r in
                        switch r {
                            case .value:
                                return try await downstream(r)
                            case .completion:
                                let finalValue = try await downstream(r)
                                try await multicaster.release()
                                return finalValue
                        }
                    }
                }
                do {
                    guard let m = try await multicaster.value() else {
                        _ = try? await downstream(.completion(.finished))
                        multicaster.cancel()
                        continuation.resume()
                        return Cancellable<Demand> { .done }
                    }
                    let cancellable = await m.publisher().sink(lift(downstream))
                    if cancellable.isCancelled {
                        fatalError("Should not be cancelled")
                    }
                    do {
                        try await m.connect()
                    }
                    catch {
                        /*
                         ignore failed connects after the first one bc
                         we have no way to prevent a race condition between
                         multiple connects
                         */
                    }
                    continuation.resume()
                    return cancellable
                } catch {
                    continuation.resume()
                    return .init { try await downstream(.completion(.finished)) }
                }
            } )
        }
    }
}
