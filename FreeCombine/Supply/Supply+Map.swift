//
//  Supply+Extensions.swift
//  FreeCombine
//
//  Created by Van Simmons on 4/23/20.
//  Copyright © 2020 ComputeCycles, LLC. All rights reserved.
//

extension Supply {
    static func map<T>(
        _ transform: @escaping (Value) -> T
    ) -> (Self) -> Supply<T, Failure> {
        { supply in
            switch supply {
                case .value(let value): return .value(transform(value))
                case .failure(let failure): return .failure(failure)
                case .finished: return .finished
                case .none: return .none
            }
        }
    }
    
    static func mapError<T>(
        _ transform: @escaping (Failure) -> T
    ) -> (Self) -> Supply<Value, T> {
        { supply in
            switch supply {
                case .value(let value): return .value(value)
                case .failure(let failure): return .failure(transform(failure))
                case .finished: return .finished
                case .none: return .none
            }
        }
    }
    
    static func tryMap<T> (
        _ transform: @escaping (Value) throws -> T
    ) -> (Self) -> Supply<T, Error> {
        { this in
            switch this {
                case .value(let v):
                    do { return .value(try transform(v)) }
                    catch { return .failure(error) }
                case .failure(let failure): return .failure(failure)
                case .none: return .none
                case .finished: return .finished
            }
        }
    }
}
