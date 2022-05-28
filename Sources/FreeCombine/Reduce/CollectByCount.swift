//
//  CollectByCount.swift
//  
//
//  Created by Van Simmons on 5/19/22.
//

public extension Publisher {
    func collectByCount(
        _ count: Int
    ) -> Publisher<[Output]> {
        return .init { continuation, downstream in
            let currentValue: ValueRef<[Output]> = ValueRef(value: [])
            return self(onStartup: continuation) { r in
                guard !Task.isCancelled else {
                    _ = try await downstream(.completion(.failure(PublisherError.cancelled)))
                    throw PublisherError.cancelled
                }
                switch r {
                    case .value(let a):
                        await currentValue.append(a)
                        return await currentValue.value.count == count
                            ? try await downstream(.value(currentValue.set(value: [])))
                            : .more
                    case let .completion(value):
                        _ = try await downstream(.value(currentValue.value))
                        return try await downstream(.completion(value))
                }
            }
        }
    }
}
