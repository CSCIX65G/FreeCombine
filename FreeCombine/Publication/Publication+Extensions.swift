//
//  Publication+Extensions.swift
//  FreeCombine
//
//  Created by Van Simmons on 4/23/20.
//  Copyright © 2020 ComputeCycles, LLC. All rights reserved.
//

extension Publication {
    func map<T>(_ transform: (Value) -> T) -> Publication<T, Failure> {
        switch self {
        case .value(let value): return .value(transform(value))
        case .failure(let failure): return .failure(failure)
        case .finished: return .finished
        case .none: return .none
        }
    }
    
    func mapError<T: Error>(_ transform: (Failure) -> T) -> Publication<Value, T> {
        switch self {
        case .value(let value): return .value(value)
        case .failure(let failure): return .failure(transform(failure))
        case .finished: return .finished
        case .none: return .none
        }
    }
}
