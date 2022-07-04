//
//  Delay.swift
//  
//
//  Created by Van Simmons on 5/27/22.
//

public extension Publisher {
    func delay(
        interval: Duration
    ) -> Self {
        .init { continuation, downstream in
            self(onStartup: continuation) { r in switch r {
                case .value:
                    do {
                        try await Task.sleep(nanoseconds: interval.inNanoseconds)
                        guard !Task.isCancelled else { throw PublisherError.cancelled }
                        return try await downstream(r)
                    }
                    catch {
                        return try await handleCancellation(of: downstream)
                    }
                case let .completion(value):
                    return try await downstream(.completion(value))
            } }
        }
    }
}
