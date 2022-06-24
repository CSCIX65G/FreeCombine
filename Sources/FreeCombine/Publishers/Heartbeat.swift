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
    init(interval: Duration) {
        self = Publisher<UInt64> { continuation, downstream  in
            .init {
                let startTime = DispatchTime.now().uptimeNanoseconds
                var ticks: UInt64 = 0
                continuation.resume()
                while true {
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
            }
        }
    }
}
