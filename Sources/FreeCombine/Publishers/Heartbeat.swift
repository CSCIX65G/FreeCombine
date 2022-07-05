//
//  Heartbeat.swift
//  
//
//  Created by Van Simmons on 5/24/22.
//
import Dispatch
public func Heartbeat(interval: Duration) -> Publisher<UInt64> {
    .init(interval: interval)
}

public extension Publisher where Output == UInt64 {
    init(interval: Duration, maxTicks: Int = Int.max) {
        self = Publisher<UInt64> { continuation, downstream  in
            .init {
                let startTime = DispatchTime.now().uptimeNanoseconds
                var ticks: UInt64 = 0
                continuation.resume()
                while ticks < maxTicks {
                    guard !Task.isCancelled else {
                        return try await handleCancellation(of: downstream)
                    }
                    ticks += 1
                    let nextTime = startTime + (ticks * interval.inNanoseconds)
                    let currentTime = DispatchTime.now().uptimeNanoseconds
                    if currentTime > nextTime { continue }
                    switch try await downstream(.value(currentTime)) {
                        case .done: return .done
                        case .more: try? await Task.sleep(nanoseconds: nextTime - currentTime)
                    }
                }
                _ = try await downstream(.completion(.finished))
                return .done
            }
        }
    }
}

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public func Heartbeat<C: Clock>(
    clock: C,
    interval: C.Instant.Duration,
    tolerance: C.Instant.Duration? = .none
) -> Publisher<C.Instant> {
    .init(clock: clock, interval: interval, tolerance: tolerance)
}

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public extension Publisher {
    init<C: Clock>(
        clock: C,
        interval: C.Instant.Duration,
        tolerance: C.Instant.Duration? = .none,
        maxTicks: Int = Int.max
    ) where Output == C.Instant {
        self = Publisher<C.Instant> { continuation, downstream  in
            .init {
                let startTime = clock.now
                var ticks: Int = .zero
                continuation.resume()
                while ticks < maxTicks {
                    guard !Task.isCancelled else {
                        return try await handleCancellation(of: downstream)
                    }
                    ticks += 1
                    let nextTime = startTime.advanced(by: interval * ticks)
                    let currentTime = clock.now
                    if currentTime > nextTime { continue }
                    switch try await downstream(.value(currentTime)) {
                        case .done: return .done
                        case .more: try await clock.sleep(until: nextTime, tolerance: tolerance)
                    }
                }
                _ = try await downstream(.completion(.finished))
                return .done
            }
        }
    }
}
