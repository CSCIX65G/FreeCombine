//
//  TryFilter.swift
//  
//
//  Created by Van Simmons on 7/3/22.
//
public extension Publisher {
    func tryFilter(
        _ isIncluded: @escaping (Output) async throws -> Bool
    ) -> Self {
        .init { continuation, downstream in
            self(onStartup: continuation) { r in switch r {
                case .value(let a):
                    do { guard try await isIncluded(a) else { return .more } }
                    catch { return try await handleCancellation(of: downstream) }
                    return try await downstream(r)
                case .completion:
                    return try await downstream(r)
            } }
        }
    }
}
