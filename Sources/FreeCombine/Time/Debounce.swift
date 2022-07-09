//
//  File.swift
//  
//
//  Created by Van Simmons on 7/8/22.
//
//init(
//    upstream: Upstream,
//    dueTime: Context.SchedulerTimeType.Stride,
//    scheduler: Context,
//    options: Context.SchedulerOptions?
//)
extension Publisher {
    private func cleanup(
        _ subject: Subject<Output>,
        _ subjectRef: ValueRef<Subject<Output>?>,
        _ cancellable: Cancellable<Demand>,
        _ cancellableRef: ValueRef<Cancellable<Demand>?>
    ) async throws  -> Void {
        try await subject.finish()
        _ = await subject.result
        await subjectRef.set(value: .none)
        _ = await cancellable.result
        await cancellableRef.set(value: .none)
    }

    func debounce(
        interval: Duration
    ) -> Self {
        .init { continuation, downstream in
            let subjectRef = ValueRef<Subject<Output>?>(value: .none)
            let cancellableRef = ValueRef<Cancellable<Demand>?>(value: .none)
            return self(onStartup: continuation) { r in
                var subject: Subject<Output>! = await subjectRef.value
                var cancellable: Cancellable<Demand>! = await cancellableRef.value
                if subject == nil {
                    subject = try await PassthroughSubject()
                    await subjectRef.set(value: subject)
                    cancellable = await subject.publisher()
                        .delayEachDemand(interval: interval)
                        .sink(downstream)
                    await cancellableRef.set(value: cancellable)
                }
                guard !Task.isCancelled && !cancellable.isCancelled else {
                    try await cleanup(subject, subjectRef, cancellable, cancellableRef)
                    return try await handleCancellation(of: downstream)
                }
                do { let _: Void = try subject.send(r) }
                catch { /* ignore failure to enqueue, that's the entire point */ }
                switch r {
                    case .value:
                        return .more
                    case .completion(.finished), .completion(.cancelled):
                        try await cleanup(subject, subjectRef, cancellable, cancellableRef)
                        return .done
                    case .completion(.failure(let error)):
                        try await cleanup(subject, subjectRef, cancellable, cancellableRef)
                        throw error
                }
            }
        }
    }
}
