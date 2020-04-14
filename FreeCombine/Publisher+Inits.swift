//
//  Publisher+Inits.swift
//  FreeCombine
//
//  Created by Van Simmons on 4/12/20.
//  Copyright © 2020 ComputeCycles, LLC. All rights reserved.
//

typealias Publisher<Output, OutputFailure: Error> =
    Composer<Never, Never, Never, Output, Never, OutputFailure>

extension Publisher {
    init(_ producer: Producer<Output, OutputFailure>) {
        composition = .publisher(
            subscribe: { subscriber in
                Subscription<OutputControl> (
                    request: curry(Self.output)(recast(subscriber))(producer),
                    control: curry(Self.finished)(subscriber)(producer)
                )
            }
        )
    }
}

// Empty
func Empty<T>(_ t: T.Type) -> Publisher<T, Never> {
    Publisher<T, Never>(Producer(produce: { _ in .done }, finish: { }))
}

// PublishedSequence
func PublishedSequence<S>(_ values: S) -> Publisher<S.Element, Never> where S: Sequence {
    var slice = ArraySlice(values)
    return Publisher<S.Element, Never>(
        Producer(
            produce: { demand in
                guard demand.intValue > 0 else { return .none }
                guard let value = slice.first else { return .done }
                slice = slice.dropFirst()
                return .some(value)
            },
            finish: { slice = ArraySlice() }
        )
    )
}

// Just
func Just<Output>(_ value: Output) -> Publisher<Output, Never> {
    PublishedSequence([value])
}
