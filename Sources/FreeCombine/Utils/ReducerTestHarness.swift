//
//  StateTestHarness.swift
//  
//
//  Created by Van Simmons on 7/2/22.
//

//distributor = try await withResumption { distResumption in
//    Task {
//        let _: Void = try await withResumption({ resumption in
//            Task {
//                var distributor = await distributorValue.value
//                _ = try await distributor.reduce(action: .receive(.value(15), resumption))
//                distResumption.resume(returning: distributor)
//            }
//        })
//    }
//}

struct ReducerTestHarness<State, Action, SyncAction, SyncResult> {
    var state: State
    var reducer: Reducer<State, Action>
    var reducerStep: (SyncAction) -> (inout State) async throws -> (Reducer<State, Action>.Effect, SyncResult)
}

//extension DistributorState {
//    enum SyncAction {
//        case receive(AsyncStream<Output>.Result)
//        case subscribe(@Sendable (AsyncStream<Output>.Result) async throws -> Demand)
//        case unsubscribe(Int)
//    }
//    enum SyncResult {
//        case cancellable(Cancellable<Demand>)
//        case done
//        case none
//    }
//
//    static func stepper(
//        _ syncAction: SyncAction
//    ) -> (inout DistributorState<Output>) async throws -> (
//        Reducer<DistributorState<Output>, DistributorState<Output>.Action>.Effect,
//        DistributorState<Output>.SyncResult
//    ) {
//        { state in
//            let stateValue = ValueRef(value: state)
//            let effectValue = ValueRef<Reducer<DistributorState<Output>, DistributorState<Output>.Action>.Effect>(value: .none)
//            let resultValue = ValueRef<DistributorState<Output>.SyncResult>(value: .none)
//            switch syncAction {
//                case .receive(let value):
//                    state = try await withResumption { distResumption in
//                        Task {
//                            let result: Void = try await withResumption({ resumption in
//                                Task {
//                                    var newState = await stateValue.value
//                                    let effect = try await newState.reduce(action: .receive(value, resumption))
//                                    await effectValue.set(value: effect)
//                                    distResumption.resume(returning: newState)
//                                }
//                            })
//                        }
//                    }
//                case .subscribe(let downstream):
//                    state = try await withResumption { distResumption in
//                        Task {
//                            let _: Cancellable<Demand> = try await withResumption({ resumption in
//                                Task {
//                                    var newState = await stateValue.value
//                                    let effect = try await newState.reduce(action: .subscribe(downstream, resumption))
//                                    await effectValue.set(value: effect)
//                                    distResumption.resume(returning: newState)
//                                }
//                            })
//                        }
//                    }
//                case .unsubscribe(let value):
//                    state = try await withResumption { distResumption in
//                        Task {
//                            var newState = await stateValue.value
//                            let effect = try await newState.reduce(action: .unsubscribe(value))
//                            await effectValue.set(value: effect)
//                            distResumption.resume(returning: newState)
//                        }
//                    }
//
//            }
//            return await effectValue.value
//        }
//    }
//}
//
//extension ReducerTestHarness {
//    init<Output: Sendable>(_ state : DistributorState<Output>)
//    where State == DistributorState<Output>,
//    Action == DistributorState<Output>.Action,
//    SyncAction == DistributorState<Output>.SyncAction {
//        self.state = state
//        self.reducer = .init(
//            onCompletion: DistributorState<Output>.complete,
//            disposer: DistributorState<Output>.dispose,
//            reducer: DistributorState<Output>.reduce
//        )
//        self.reducerStep = DistributorState<Output>.stepper
//    }
//}
