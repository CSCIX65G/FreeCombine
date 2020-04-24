//
//  Producer+Statics.swift
//  FreeCombine
//
//  Created by Van Simmons on 4/12/20.
//  Copyright © 2020 ComputeCycles, LLC. All rights reserved.
//

extension Producer {
    static func empty() -> Producer {
        return Producer({ _ in .finished })
    }
    
    static func just(_ value: Value) -> Producer {
        var hasPublished = false
        return Producer({ demand in
            guard !hasPublished else { return .none }
            hasPublished = true
            return .value(value)
        })
    }
    
    static func sequence<S: Sequence>(_ values: S) -> Producer
        where S.Element == Value
    {
        var slice = ArraySlice(values)
        return .init(
            .init { request in
                guard case .demand(let demand) = request else {
                    slice = ArraySlice()
                    return .finished
                }
                guard demand.quantity > 0 else { return .none }
                guard let value = slice.first else { return .finished }
                slice = slice.dropFirst()
                return .value(value)
            }
        )
    }
}
