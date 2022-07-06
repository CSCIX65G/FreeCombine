//
//  Throttle.swift
//  
//
//  Created by Van Simmons on 7/4/22.
//
//func throttle<S>(for interval: S.SchedulerTimeType.Stride, scheduler: S, latest: Bool) -> Publishers.Throttle<Self, S>
import Atomics
extension Publisher {
    func throttle(
        interval: Duration,
        latest: Bool
    ) -> Self {
        .init { continuation, downstream in
            let subjectRef = ValueRef<Subject<Output>?>(value: .none)
            let cancellableRef = ValueRef<Cancellable<Demand>?>(value: .none)
            return self(onStartup: continuation) { r in
                var subject: Subject<Output>! = await subjectRef.value
                var cancellable: Cancellable<Demand>! = await cancellableRef.value
                if subject == nil {
                    subject = try await PassthroughSubject(
                        buffering: latest ? .bufferingNewest(1) : .bufferingOldest(1)
                    )
                    await subjectRef.set(value: subject)
                    cancellable = await subject.publisher().throttleDemand(interval: interval).sink(downstream)
                    await cancellableRef.set(value: cancellable)
                }
                guard !Task.isCancelled && !cancellable.isCancelled else {
                    try await subject.finish()
                    await subjectRef.set(value: .none)
                    _ = await subject.result
                    await cancellableRef.set(value: cancellable)
                    _ = await cancellable.result
                    return try await handleCancellation(of: downstream)
                }
                do { let _: Void = try subject.send(r) }
                catch { }
                switch r {
                    case .value:
                        return .more
                    case .completion(.finished), .completion(.cancelled):
                        try await subject.finish()
                        await subjectRef.set(value: .none)
                        _ = await subject.result
                        await cancellableRef.set(value: cancellable)
                        _ = await cancellable.result
                        return .done
                    case .completion(.failure(let error)):
                        try await subject.finish()
                        await subjectRef.set(value: .none)
                        _ = await subject.result
                        await cancellableRef.set(value: cancellable)
                        _ = await cancellable.result
                        throw error
                }
            }
        }
    }
}
