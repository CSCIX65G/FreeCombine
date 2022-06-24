//
//  Share.swift
//  
//
//  Created by Van Simmons on 6/7/22.
//

public extension Publisher {
    /// Share inescapably violates the no leak policy of this library.  To be avoided.
    func share() async -> Self {
        let multicaster = await LazyValueRef(
            deinitBehavior: .silentCancel,
            creator: {  await Multicaster<Output>.init(
                stateTask: try Channel.init(buffering: .unbounded)
                    .stateTask(
                        deinitBehavior: .silentCancel,
                        initialState: MulticasterState<Output>.create(upstream: self),
                        reducer: Reducer(
                            onCompletion: MulticasterState<Output>.complete,
                            disposer: MulticasterState<Output>.dispose,
                            reducer: MulticasterState<Output>.reduce
                        )
                    )
            ) },
            disposer: { value in
                await value.finish()
            }
        )
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
        return .init { continuation, downstream in
            Cancellable<Cancellable<Demand>>.join(.init {
                do {
                    guard let m = try await multicaster.value() else {
                        _ = try? await downstream(.completion(.finished))
                        multicaster.cancel()
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
                    continuation?.resume()
                    return cancellable
                } catch {
                    throw error
                }
            } )
        }
    }
}
