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
            self(onStartup: continuation) { r in
                guard !Task.isCancelled else {
                    return try await handleCancellation(of: downstream)
                }
                switch r {
                    case .value:
                        do { try await Task.sleep(nanoseconds: interval.inNanoseconds) }
                        catch {
                            guard !Task.isCancelled else {
                                return try await handleCancellation(of: downstream)
                            }
                            return try await downstream(.completion(.failure(error)))
                        }
                        return try await downstream(r)
                    case let .completion(value):
                        return try await downstream(.completion(value))
                }
            }
        }
    }
}
