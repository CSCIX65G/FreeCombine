//
//  Publisher+FlatMap.swift
//  FreeCombine
//
//  Created by Van Simmons on 4/17/20.
//  Copyright © 2020 ComputeCycles, LLC. All rights reserved.
//

public extension Publisher {
    func flatMap<T>(
        _ transform: @escaping (Output) -> Publisher<T, Failure>
    ) -> Publisher<T, Failure> {
        transformation(
            joinSubscriber: Subscriber<T, Failure>.filterJoin({_ in true}),
            transformPublication: { publication in
                switch publication {
                case .value(let value):
                    let publisher = transform(value)
                    var first: Publication<T, Failure>?
                    let subscription = publisher.sink { first = $0 }
                    subscription(.demand(.max(1)))
                    guard let current = first else {
                        fatalError("Add asyncrony")
                    }
                    return current
                case .none: return .none
                case .failure(let failure): return .failure(failure)
                case .finished: return .finished                    }
            },
            transformRequest: {
                switch $0 {
                case .cancel: return .cancel
                case .demand: return .demand(.max(1))
                }
            }
        )
    }
}


