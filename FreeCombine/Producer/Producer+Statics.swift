//
//  Producer+Statics.swift
//  FreeCombine
//
//  Created by Van Simmons on 4/12/20.
//  Copyright © 2020 ComputeCycles, LLC. All rights reserved.
//

public extension Producer where Failure == Never {
    static func empty() -> Producer<Value, Never> {
        Producer { _ in .finished }
    }
    
    static func just(_ value: Value) -> Producer<Value, Never> {
        var hasPublished = false
        return Producer { demand in
            guard !hasPublished else { return .finished }
            guard demand.unsatisfied else { return .none }
            hasPublished = true
            return .value(value)
        }
    }
    
    static func sequence<S: Sequence>(_ values: S) -> Producer<Value, Never>
        where S.Element == Value
    {
        var slice = ArraySlice(values)
        return .init { demand in
            switch demand {
            case .none:
                return .none
            case .cancel:
                slice = ArraySlice()
                return .finished
            case .max, .unlimited:
                guard let value = slice.first else { return .finished }
                slice = slice.dropFirst()
                return .value(value)
            }
        }
    }
}
