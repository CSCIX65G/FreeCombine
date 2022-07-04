//
//  Delay.swift
//  
//
//  Created by Van Simmons on 7/4/22.
//
import Atomics
public extension Publisher {
    func delay(
        interval: Duration
    ) -> Self {
        .init { continuation, downstream in
            let shouldDelay = ManagedAtomic<Bool>(true)
            return self(onStartup: continuation) { r in
                if shouldDelay.exchange(false, ordering: .sequentiallyConsistent) {
                    try await Task.sleep(nanoseconds: interval.inNanoseconds)
                    guard !Task.isCancelled else { return try await handleCancellation(of: downstream) }
                }
                return try await downstream(r)
            }
        }
    }
}
