//
//  FlatMap.swift
//  
//
//  Created by Van Simmons on 5/18/22.
//
public extension Publisher {
    func flatMap<B>(
        _ f: @escaping (Output) async -> Publisher<B>
    ) -> Publisher<B> {
        .init { continuation, downstream in
            self(onStartup: continuation) { r in guard !Task.isCancelled else { return .done }; switch r {
                case .value(let a):
                    let p = await f(a)
                    let c = await p(flattener(downstream))
                    return try await c.task.value
                case let .completion(value):
                    return try await downstream(.completion(value))
            } }
        }
    }
}
