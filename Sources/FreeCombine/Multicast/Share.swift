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
                stateTask: Channel.init().stateTask(
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
                        let finalValue = try await downstream(r)
                        try await multicaster.release()
                        return finalValue
                }
            }
        }
        return .init { continuation, downstream in
            Cancellable<Cancellable<Demand>>.join(.init {
                let m = try await multicaster.value()
                try await multicaster.retain()
                let cancellable = await m.publisher().sink(lift(downstream))
                try await m.connect()
                continuation?.resume()
                return cancellable
            } )
        }
    }
}
