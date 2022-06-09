//
//  Share.swift
//  
//
//  Created by Van Simmons on 6/7/22.
//

// Need join on Cancellable
public extension Publisher {

    func share() async -> Self {
        let multicaster: ValueRef<Multicaster<Output>?> = ValueRef(value: .none)
        @Sendable func lift(
            _ downstream: @Sendable @escaping (AsyncStream<Output>.Result) async throws -> Demand
        ) -> @Sendable (AsyncStream<Output>.Result) async throws -> Demand {
            { r in
                switch r {
                    case .value:
                        return try await downstream(r)
                    case .completion:
                        let ret = try await downstream(r)
                        await multicaster.set(value: .none)
                        return ret
                }
            }
        }
        return .init { continuation, downstream in
            Cancellable<Cancellable<Demand>>.join(.init {
                if await multicaster.value == nil {
                    let m: Multicaster<Output> = await .init(
                        stateTask: Channel.init().stateTask(
                            initialState: MulticasterState<Output>.create(upstream: self),
                            reducer: Reducer(
                                onCompletion: MulticasterState<Output>.complete,
                                reducer: MulticasterState<Output>.reduce
                            )
                        )
                    )
                    await multicaster.set(value: m)
                    let cancellable = await m.publisher().sink(lift(downstream))
                    try await m.connect()
                    _ = print("\(m)")
                    return cancellable
                }
                guard let m = await multicaster.value else {
                    return await Empty(Output.self).sink(downstream)
                }
                let cancellable = await m.publisher().sink(lift(downstream))
                _ = print("\(m)")
                return cancellable
            } )
        }
    }
}
