//
//  Catch.swift
//  
//
//  Created by Van Simmons on 6/7/22.
//
public extension Publisher {
    func `catch`(_ f: @escaping (Swift.Error) async -> Publisher<Output>) -> Publisher<Output> {
        flatMapError(f)
    }
}
