//
//  Publication+Throws.swift
//  FreeCombine
//
//  Created by Van Simmons on 4/27/20.
//  Copyright © 2020 ComputeCycles, LLC. All rights reserved.
//

extension Publication {
    static func catchMap<T>(
        _ transform: @escaping (Value) throws -> T
    ) -> (Self) -> Publication<Result<T, Error>, Error> {
         { $0.catchMap(transform) }
    }
    
    func catchMap<T>(
        _ transform: (Value) throws -> T
    ) -> Publication<Result<T, Error>, Error> {
        switch self {
        case .value(let v):
            let result: Result<T, Error>
            do { result = .success(try transform(v)) }
            catch { result = .failure(error) }
            return .value(result)
        case .failure(let failure): return .failure(failure)
        case .finished: return .finished
        case .none: return .none
        }
    }
    
    static func tryMap<T> (
        _ transform: @escaping (Value) throws -> T
    ) -> (Self) -> Publication<T, Error> {
        { this in
            switch this {
            case .value(let v):
                do { return .value(try transform(v)) }
                catch { return .failure(error) }
            case .failure(let failure):
                return .failure(failure)
            case .none:
                return .none
            case .finished:
                return .finished
            }

        }
    }
}
