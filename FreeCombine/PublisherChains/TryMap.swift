//
//  TryMap.swift
//  FreeCombine
//
//  Created by Van Simmons on 4/25/20.
//  Copyright © 2020 ComputeCycles, LLC. All rights reserved.
//

//extension Func {
//    static func catching(_ f: (A) throws -> B) -> Func<A, Result<B, Error>> {
//        .init {
//            do { return .success(try f($0)) }
//            catch { return .failure(error) }
//        }
//    }
//}

// TODO: Implement tryMap
//public extension Publisher {
//    func tryMap<T>(_ transform: @escaping (Output) throws -> T) -> Publisher<T, Failure> {
//        //public struct Publisher<T, Failure: Error> {
//        //    public let call: (Subscriber<T, Failure>) -> Subscription
//        //}
//
//        let hoist = { (downstream: Subscriber<T, Failure>) -> Subscriber<Output, Failure> in
//            downstream.contraMap(Func.catching(transform))
//        }
//        
//        let lower = { (upstream: Subscription) -> Subscription in
//            upstream
//        }
//        
//        return .init(dimap(hoist, lower))
//    }
//}
