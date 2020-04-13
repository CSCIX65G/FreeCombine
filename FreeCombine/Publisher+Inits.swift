//
//  Publisher+Inits.swift
//  FreeCombine
//
//  Created by Van Simmons on 4/12/20.
//  Copyright © 2020 ComputeCycles, LLC. All rights reserved.
//

typealias Publisher<Output, OutputFailure: Error> =
    Composer<Never, Never, Never, Output, Never, OutputFailure>

let neverSubscribing = Subscriber<Never, Never, Never>(input: { _ in .none }, completion: void)
let voidSubscription = Subscription<Never>(request: void, control: void)

extension Publisher {
    init(_ producer: Producer<Output, OutputFailure>) {
        self.liftSubscriber = {_ in recast(neverSubscribing) }
        self.subscribe = {_, _ in recast(voidSubscription) }
        self.lowerSubscription = { subscriber, _ in
            Subscription<OutputControl> (
                request: curry(Self.output)(recast(subscriber))(producer),
                control: curry(Self.finished)(subscriber)(producer)
            )
        }
    }
}

// Empty
func Empty<T>(_ t: T.Type) -> Publisher<T, Never> {
    Publisher<T, Never>( Producer(produce: { _ in .done }, finish: { }))
}

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
