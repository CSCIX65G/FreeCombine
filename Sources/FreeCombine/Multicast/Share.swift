//
//  Share.swift
//  
//
//  Created by Van Simmons on 6/7/22.
//

// Need join on Cancellable
public extension Publisher {
    func share() async -> Self {
        let multicaster = await LazyValueRef(
            creator: {  await Multicaster<Output>.init(
                stateTask: Channel.init(buffering: .unbounded).stateTask(
                    initialState: MulticasterState<Output>.create(upstream: self),
                    reducer: Reducer(
                        onCompletion: MulticasterState<Output>.complete,
                        disposer: MulticasterState<Output>.dispose,
                        reducer: MulticasterState<Output>.reduce
                    )
                )
            ) }
        )
        @Sendable func lift(
            _ downstream: @Sendable @escaping (AsyncStream<Output>.Result) async throws -> Demand
        ) -> @Sendable (AsyncStream<Output>.Result) async throws -> Demand {
            { r in
                switch r {
                    case .value:
                        return try await downstream(r)
                    case .completion:
//                        try await multicaster.release()
                        let finalValue = try await downstream(r)
                        return finalValue
                }
            }
        }
        return .init { continuation, downstream in
            Cancellable<Cancellable<Demand>>.join(.init {
                do {
                    guard let m = try await multicaster.value() else {
                        return Cancellable<Demand> { .done }
                    }
                    let cancellable = await m.publisher().sink(lift(downstream))
                    if cancellable.isCancelled {
                        fatalError("Should not be cancelled")
                    }
                    do {
                        try await m.connect()
                    }
                    catch { /* ignore failed connects after the first one */ }
                    continuation?.resume()
                    return cancellable
                } catch {
                    throw error
                }
            } )
        }
    }
}
