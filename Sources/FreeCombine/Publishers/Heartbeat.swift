//
//  Heartbeat.swift
//  
//
//  Created by Van Simmons on 5/24/22.
//
//  Copyright 2022, ComputeCycles, LLC
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//
import Dispatch
public func Heartbeat(interval: Duration) -> Publisher<UInt64> {
    .init(interval: interval)
}

public extension Publisher where Output == UInt64 {
    init(interval: Duration, maxTicks: Int = Int.max, tickAtStart: Bool = false) {
        self = Publisher<UInt64> { resumption, downstream  in
            .init {
                var ticks: UInt64 = 0
                resumption.resume()
                var maxTicks = maxTicks
                do {
                    let start = DispatchTime.now().uptimeNanoseconds
                    var current = start
                    if tickAtStart {
                        maxTicks -= 1
                        guard try await downstream(.value(current)) != .done else {
                            return .done
                        }
                    }
                    while ticks < maxTicks {
                        guard !Task.isCancelled else {
                            return try await handleCancellation(of: downstream)
                        }
                        ticks += 1
                        let next = start + (ticks * interval.inNanoseconds)
                        current = DispatchTime.now().uptimeNanoseconds
                        if current > next { continue }
                        try? await Task.sleep(nanoseconds: next - current)
                        current = DispatchTime.now().uptimeNanoseconds
                        guard try await downstream(.value(current)) != .done else {
                            return .done
                        }
                    }
                    _ = try await downstream(.completion(.finished))
                } catch {
                    throw error
                }
                return .done
            }
        }
    }
}

#if swift(>=5.7)
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
        maxTicks: Int = Int.max,
        tickAtStart: Bool = false
    ) where Output == C.Instant {
        self = Publisher<C.Instant> { resumption, downstream  in
                .init {
                    let start = clock.now
                    var ticks: Int = .zero
                    resumption.resume()
                    var maxTicks = maxTicks
                    do {
                        var current = start
                        if tickAtStart {
                            maxTicks -= 1
                            guard try await downstream(.value(current)) != .done else {
                                return .done
                            }
                        }
                        while ticks < maxTicks {
                            guard !Task.isCancelled else {
                                return try await handleCancellation(of: downstream)
                            }
                            ticks += 1
                            let next = start.advanced(by: interval * ticks)
                            current = clock.now
                            if current > next { continue }
                            try await clock.sleep(until: next, tolerance: tolerance)
                            current = clock.now
                            guard try await downstream(.value(current)) != .done else {
                                return .done
                            }
                        }
                        _ = try await downstream(.completion(.finished))
                    } catch {
                        throw error
                    }
                    return .done
                }
        }
    }
}
#endif
