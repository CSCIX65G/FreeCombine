//
//  Share.swift
//  
//
//  Created by Van Simmons on 6/7/22.
//
public extension Publisher {
//    func share() async -> Self {
//        let multicaster: ValueRef<Multicaster<Output>?> = ValueRef(value: .none)
//        return .init { continuation, downstream in
//            return self(onStartup: continuation) { r in
//                if await multicaster.value == nil {
//                    let m: Multicaster<Output> = await .init(
//                        stateTask: Channel.init().stateTask(
//                            initialState: MulticasterState<Output>.create(upstream: self),
//                            reducer: Reducer(
//                                onCompletion: MulticasterState<Output>.complete,
//                                reducer: MulticasterState<Output>.reduce
//                            )
//                        )
//                    )
//                    await multicaster.set(value: m)
//                    try await m.connect()
//                }
//                guard let m = await multicaster.value else {
//                    fatalError("Lost connection")
//                }
//                switch r {
//                    case .value(let a):
//                        return try await downstream(.value(a))
//                    case let .completion(value):
//                        try await m.disconnect()
//                        return .done
//                }
//            }
//        }
//    }
}
