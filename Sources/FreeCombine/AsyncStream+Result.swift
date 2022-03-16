//
//  AsyncStream+Result.swift
//  
//
//  Created by Van Simmons on 3/15/22.
//

public extension AsyncStream {
    enum Result {
        case value(Element)
        case failure(Error)
        case terminated
    }
}
