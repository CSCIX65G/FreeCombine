//
//  Publisher+Inits.swift
//  FreeCombine
//
//  Created by Van Simmons on 4/12/20.
//  Copyright © 2020 ComputeCycles, LLC. All rights reserved.
//

typealias Publisher<Output, OutputFailure: Error> =
    PubSub<Never, Never, Never, Output, Never, OutputFailure>

let neverSubscribing = Subscribing<Never, Never, Never>(input: { _ in .none }, completion: void)
let voidSubscription = Subscription<Never>(request: void, control: void)

extension Publisher {
    init(_ produce: @escaping (Demand) -> Supply<Output, OutputFailure>) {
        self.liftSubscriber = {_ in recast(neverSubscribing) }
        self.subscribe = {_, _ in recast(voidSubscription) }
        self.lowerSubscription = { subscriber, _ in
            Subscription<OutputControl> (
                request: curry(Self.output)(recast(subscriber))(produce),
                control: curry(Self.finished)(subscriber)
            )
        }
    }
}

// Empty
func Empty<T>(_ t: T.Type) -> Publisher<T, Never> {
    Publisher<T, Never> { _ in .done }
}

func PublishedSequence<S>(_ values: S) -> Publisher<S.Element, Never> where S: Sequence {
    var slice = ArraySlice(values)
    return Publisher<S.Element, Never> { demand in
        guard demand.intValue > 0 else { return .none }
        guard let value = slice.first else { return .done }
        slice = slice.dropFirst()
        return .some(value)
    }
}

// Just
func Just<Output>(_ value: Output) -> Publisher<Output, Never> {
    PublishedSequence([value])
}
