//
//  Effect.swift
//  
//
//  Created by Van Simmons on 4/12/22.
//

public enum Effect<T> {
    case none
    case fireAndForget(() -> Void)
    case published(Publisher<T>)
}
