//
//  Publisher+FlatMap.swift
//  FreeCombine
//
//  Created by Van Simmons on 4/17/20.
//  Copyright © 2020 ComputeCycles, LLC. All rights reserved.
//

extension Subscriber {
    static var substitutionJoin: (Self) -> (Self) {
        let ref = Reference<Demand>(.max(1))
        return { downstream in
            .init { supply in
                switch supply {
                case .value:
                    return ref.set(downstream(supply))
                case .failure:
                    return downstream(supply)
                case .none, .finished:
                    return ref.value
                }
            }
        }
    }
}

public extension Publisher {
    func flatMap<T>(
        _ transform: @escaping (Output) -> Publisher<T, Failure>
    ) -> Publisher<T, Failure> {
        transformation(
            joinSubscriber: Subscriber<T, Failure>.substitutionJoin,
            transformSupply: { supply in
                switch supply {
                case .value(let value):
                    let publisher = transform(value)
                    var first: Supply<T, Failure>?
                    let subscription = publisher.sink { first = $0 }
                    subscription(.max(1))
                    guard let current = first else { fatalError("Add asynchrony") }
                    return current
                case .none: return .none
                case .failure(let failure): return .failure(failure)
                case .finished: return .finished                    }
            },
            transformDemand: {
                switch $0 {
                case .cancel: return .cancel
                default: return .max(1)
                }
            }
        )
    }
}


