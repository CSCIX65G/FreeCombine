//
//  Throttle.swift
//  
//
//  Created by Van Simmons on 7/4/22.
//
//func throttle<S>(for interval: S.SchedulerTimeType.Stride, scheduler: S,
// latest: Bool) -> Publishers.Throttle<Self, S>
import Atomics
extension Publisher {
    func throttle(
        interval: Duration,
        latest: Bool
    ) -> Self {
        .init { continuation, downstream in
//            let nextDateTime = ManagedAtomic<Double>(true)
            self(onStartup: continuation) { r in switch r {
                case .value(let a):
                    return try await downstream(.value(a))
                case let .completion(value):
                    return try await downstream(.completion(value))
            } }
        }
    }
}
