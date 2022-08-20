//
//  Throttle.swift
//  
//
//  Created by Van Simmons on 7/4/22.
//

extension Publisher {
    enum ThrottlerError: Error {
        case alreadyActivated
    }
    class Throttler {
        private(set) var subject: Subject<Output>!
        private(set) var cancellable: Cancellable<Demand>!
        private(set) var timerCancellable: Cancellable<Demand>!

        var value: AsyncStream<Output>.Result? = .none
        func set(value: AsyncStream<Output>.Result?) { self.value = value }
        var completion: AsyncStream<Output>.Result? = .none
        func set(completion: AsyncStream<Output>.Result?) { self.completion = completion }

        func activate (
            interval: Duration,
            latest: Bool = false,
            downstream: @escaping @Sendable (AsyncStream<Output>.Result) async throws -> Demand
        ) async throws -> Void {
            guard subject == nil else { return }
            subject = try await PassthroughSubject(buffering: .bufferingNewest(1))
            cancellable = await subject.asyncPublisher.sink(downstream)
            timerCancellable = await Heartbeat(interval: interval).sink { _ in
                if let value = self.value {
                    try await self.subject.blockingSend(value)
                    self.set(value: .none)
                }
                if let completion = self.completion {
                    try await self.subject.blockingSend(completion)
                    try await self.cleanup()
                }
            }
        }

        fileprivate func cleanup() async throws  -> Void {
            _ = await timerCancellable.cancelAndAwaitResult()
            try await subject.finish()
            _ = await cancellable.result
            _ = await subject.result
        }
    }

    func throttle(
        interval: Duration,
        latest: Bool = false,
        bufferSize: Int = 1
    ) -> Self {
        .init { continuation, downstream in
            let throttler: Throttler = .init()
            return self(onStartup: continuation) { r in
                try await throttler.activate(interval: interval, latest: latest, downstream: downstream)

                // Check for cancellation
                let isCancelled = throttler.cancellable.isCancelled
                guard !Task.isCancelled && !isCancelled else {
                    try await throttler.cleanup()
                    return try await handleCancellation(of: downstream)
                }

                switch r {
                    case .value:
                        let value = throttler.value
                        if value == nil || latest { throttler.set(value: r); return .more }
                        return .more
                    case .completion(.finished), .completion(.cancelled):
                        throttler.set(completion: r)
                        return try await throttler.cancellable.value
                    case .completion(.failure(let error)):
                        throttler.set(completion: r)
                        _ = try await throttler.cancellable.value
                        throw error
                }
            }
        }
    }
}
