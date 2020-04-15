//
//  Publisher+Inits.swift
//  FreeCombine
//
//  Created by Van Simmons on 4/12/20.
//  Copyright © 2020 ComputeCycles, LLC. All rights reserved.
//

struct Publication<Output, ControlValue, Failure: Error> {
    typealias RequestGenerator = (Subscriber<Output, Failure>) -> (Demand) -> Void
    typealias ControlGenerator = (Subscriber<Output, Failure>) -> (Control<ControlValue>) -> Void
    
    var request: RequestGenerator
    var control: ControlGenerator
    
    init(
        _ producer: Producer<Output, Failure>,
        _ request: RequestGenerator? = nil,
        _ control: ControlGenerator? = nil
    ) {
        self.request = request ?? Self.output(producer)
        self.control = control ?? Self.finished(producer)
    }

    func receive(subscriber: Subscriber<Output, Failure>) -> Subscription<ControlValue> {
        .init(request: subscriber |> request, control: subscriber |> control)
    }
}

extension Publication {
    var publisher: Publisher<Output, ControlValue, Failure,Output, ControlValue, Failure> {
        Publisher(hoist: identity, convert: receive, lower: identity)
    }
}

// Empty
func Empty<T>(_ t: T.Type) -> Publisher<T, Never, Never, T, Never, Never> {
    Publication(Producer(produce: { _ in .done }, finish: { })).publisher
}

// PublishedSequence
func PublishedSequence<S>(_ values: S) -> Publisher<S.Element, Never, Never, S.Element, Never, Never>
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
func Just<Output>(_ value: Output) -> Publisher<Output, Never, Never, Output, Never, Never> {
    PublishedSequence([value])
}
