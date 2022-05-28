//
//  Heartbeat.swift
//  
//
//  Created by Van Simmons on 5/24/22.
//
import Dispatch
public func Heartbeat(
    onCancel: @Sendable @escaping () -> Void = { },
    interval: Duration
) -> Publisher<UInt64> {
    .init(onCancel: onCancel, interval: interval)
}

public extension Publisher where Output == UInt64 {
    init(
        onCancel: @Sendable @escaping () -> Void = { },
        interval: Duration
    ) {
        self = Publisher<UInt64> { continuation, downstream  in
            .init { try await withTaskCancellationHandler(handler: onCancel) {
                let startTime = DispatchTime.now().uptimeNanoseconds
                var ticks: UInt64 = 0
                continuation?.resume()
                while true {
                    guard !Task.isCancelled else {
                        _ = try await downstream(.completion(.failure(PublisherError.cancelled)))
                        throw PublisherError.cancelled
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
            } }
        }
    }
}
