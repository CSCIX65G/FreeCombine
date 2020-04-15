//
//  Publisher+Inits.swift
//  FreeCombine
//
//  Created by Van Simmons on 4/12/20.
//  Copyright © 2020 ComputeCycles, LLC. All rights reserved.
//

public typealias UnfailingPublisher<T> = Publisher<T, Never, Never, T, Never, Never>

// Empty
public func Empty<T>(_ t: T.Type) -> UnfailingPublisher<T> {
    UnfailingPublisher<T>(Producer(produce: { _ in .done }, finish: { }))
}

// PublishedSequence
public func PublishedSequence<S>(_ values: S) -> UnfailingPublisher<S.Element>
    where S: Sequence {
    var slice = ArraySlice(values)
    return UnfailingPublisher<S.Element>(
        Producer(
            produce: { demand in
                guard demand.quantity > 0 else { return .none }
                guard let value = slice.first else { return .done }
                slice = slice.dropFirst()
                return .some(value)
            },
            finish: { slice = ArraySlice() }
        )
    )
}

// Just
public func Just<T>(_ value: T) -> UnfailingPublisher<T> {
    PublishedSequence([value])
}
