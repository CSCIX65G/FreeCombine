//
//  Producer+Statics.swift
//  FreeCombine
//
//  Created by Van Simmons on 4/12/20.
//  Copyright © 2020 ComputeCycles, LLC. All rights reserved.
//

extension Producer where Failure == Never {
    static func empty() -> Producer<Value, Never> {
        return Producer({ _ in .finished })
    }
    
    static func just(_ value: Value) -> Producer<Value, Never> {
        var hasPublished = false
        return Producer({ demand in
            guard !hasPublished else { return .none }
            hasPublished = true
            return .value(value)
        })
    }
    
    static func sequence<S: Sequence>(_ values: S) -> Producer<Value, Never>
        where S.Element == Value
    {
        var slice = ArraySlice(values)
        return .init(
            .init { demand in
                guard case .cancel = demand else {
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
