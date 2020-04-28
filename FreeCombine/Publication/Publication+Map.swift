//
//  Publication+Extensions.swift
//  FreeCombine
//
//  Created by Van Simmons on 4/23/20.
//  Copyright © 2020 ComputeCycles, LLC. All rights reserved.
//

extension Publication {
    static func map<T>(
        _ transform: @escaping (Value) -> T
    ) -> (Self) -> Publication<T, Failure> {
         {
            switch $0 {
            case .value(let value): return .value(transform(value))
            case .failure(let failure): return .failure(failure)
            case .finished: return .finished
            case .none: return .none
            }
        }
    }
        
    static func mapError<T>(
        _ transform: @escaping (Failure) -> T
    ) -> (Self) -> Publication<Value, T> {
        {
            switch $0 {
            case .value(let value): return .value(value)
            case .failure(let failure): return .failure(transform(failure))
            case .finished: return .finished
            case .none: return .none
            }
        }
    }
}
