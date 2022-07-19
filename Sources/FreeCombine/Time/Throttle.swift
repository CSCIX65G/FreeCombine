//
//  Throttle.swift
//  
//
//  Created by Van Simmons on 7/4/22.
//

extension Publisher {
    private func cleanup(
        _ subject: Subject<Output>,
        _ subjectRef: ValueRef<Subject<Output>?>,
        _ cancellable: Cancellable<Demand>,
        _ cancellableRef: ValueRef<Cancellable<Demand>?>,
        _ timerCancellableRef: ValueRef<Cancellable<Demand>?>
    ) async throws  -> Void {
        let timerCancellable = await timerCancellableRef.value
        _ = await timerCancellable?.cancelAndAwaitResult()
        await timerCancellableRef.set(value: .none)
        try await subject.finish()
        _ = await cancellable.result
        await cancellableRef.set(value: .none)
        _ = await subject.result
        await subjectRef.set(value: .none)
    }

    func throttle(
        interval: Duration,
        latest: Bool = false,
        bufferSize: Int = 1
    ) -> Self {
        .init { continuation, downstream in
            let subjectRef = ValueRef<Subject<Output>?>(value: .none)
            let cancellableRef = ValueRef<Cancellable<Demand>?>(value: .none)
            let valueRef = ValueRef<AsyncStream<Output>.Result?>(value: .none)
            let completionRef = ValueRef<AsyncStream<Output>.Result?>(value: .none)
            let timerCancellableRef = ValueRef<Cancellable<Demand>?>(value: .none)
            return self(onStartup: continuation) { r in
                var vSubject: Subject<Output>! = await subjectRef.value
                var vCancellable: Cancellable<Demand>! = await cancellableRef.value
                if vSubject == nil {
                    vSubject = try await PassthroughSubject(buffering: .bufferingNewest(1))
                    await subjectRef.set(value: vSubject)
                    vCancellable = await vSubject.publisher().sink(downstream)
                    await cancellableRef.set(value: vCancellable)
                }
                var timerCancellable: Cancellable<Demand>! = await timerCancellableRef.value
                let subject = vSubject!
                let cancellable = vCancellable!
                if timerCancellable == nil {
                    timerCancellable = await Heartbeat(interval: interval).sink { _ in
                        if let value = await valueRef.value {
                            try await subject.send(value)
                            await valueRef.set(value: .none)
                        }
                        if let completion = await completionRef.value {
                            try await subject.send(completion)
                            try await cleanup(subject, subjectRef, cancellable, cancellableRef, timerCancellableRef)
                        }
                    }
                    await timerCancellableRef.set(value: timerCancellable)
                }
                guard !Task.isCancelled && !cancellable.isCancelled else {
                    try await cleanup(subject, subjectRef, cancellable, cancellableRef, timerCancellableRef)
                    return try await handleCancellation(of: downstream)
                }

                switch r {
                    case .value:
                        let value = await valueRef.value
                        if value == nil || latest {
                            await valueRef.set(value: r); return .more
                        }
                        return .more
                    case .completion(.finished), .completion(.cancelled):
                        _ = await completionRef.set(value: r)
                        return try await cancellable.value
                    case .completion(.failure(let error)):
                        _ = await completionRef.set(value: r)
                        _ = try await cancellable.value
                        throw error
                }
            }
        }
    }
}
