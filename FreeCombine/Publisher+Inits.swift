//
//  Publisher+Inits.swift
//  FreeCombine
//
//  Created by Van Simmons on 4/12/20.
//  Copyright © 2020 ComputeCycles, LLC. All rights reserved.
//

// Empty
func Empty<T>(_ t: T.Type) -> Publication<T, Never, Never, T, Never, Never> {
    Publisher(Producer(produce: { _ in .done }, finish: { })).publication
}

// PublishedSequence
func PublishedSequence<S>(_ values: S) -> Publication<S.Element, Never, Never, S.Element, Never, Never>
    where S: Sequence {
    var slice = ArraySlice(values)
    return Publisher(
        Producer(
            produce: { demand in
                guard demand.quantity > 0 else { return .none }
                guard let value = slice.first else { return .done }
                slice = slice.dropFirst()
                return .some(value)
            },
            finish: { slice = ArraySlice() }
        )
    ).publication
}

// Just
func Just<Output>(_ value: Output) -> Publication<Output, Never, Never, Output, Never, Never> {
    PublishedSequence([value])
}
