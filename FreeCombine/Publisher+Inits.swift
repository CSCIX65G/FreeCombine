//
//  Publisher+Inits.swift
//  FreeCombine
//
//  Created by Van Simmons on 4/12/20.
//  Copyright © 2020 ComputeCycles, LLC. All rights reserved.
//

typealias UnfailingPublication<T> = Publisher<T, Never, Never, T, Never, Never>

// Empty
func Empty<T>(_ t: T.Type) -> UnfailingPublication<T> {
    Publication(Producer(produce: { _ in .done }, finish: { })).publisher
}

// PublishedSequence
func PublishedSequence<S>(_ values: S) -> UnfailingPublication<S.Element>
    where S: Sequence {
    var slice = ArraySlice(values)
    return Publication(
        Producer(
            produce: { demand in
                guard demand.quantity > 0 else { return .none }
                guard let value = slice.first else { return .done }
                slice = slice.dropFirst()
                return .some(value)
            },
            finish: { slice = ArraySlice() }
        )
    ).publisher
}

// Just
func Just<T>(_ value: T) -> UnfailingPublication<T> {
    PublishedSequence([value])
}
