//
//  FreeCombine.swift
//  FreeCombine
//
//  Created by Van Simmons on 4/6/20.
//  Copyright © 2020 ComputeCycles, LLC. All rights reserved.
//

enum Demand {
    case none
    case max(Int)
    case unlimited
    
    var quantity: Int {
        switch self {
        case .none: return 0
        case .max(let val): return val
        case .unlimited: return Int.max
        }
    }
}

enum Supply<Value, Failure> {
    case none
    case some(Value)
    case done
}

struct Producer<Value, Failure> {
    var produce: (Demand) -> Supply<Value, Failure>
    var finish: () -> Void
}

enum Completion<Failure: Error> {
    case finished
    case error(Failure)
}

struct Subscriber<Input, Failure: Error> {
    let input: (Input) -> Demand
    let completion: (Completion<Failure>) -> Void
}

enum Control<Value> {
    case finish
    case control(Value)
}

class Subscription<ControlValue> {
    let request: (Demand) -> Void
    let control: (Control<ControlValue>) -> Void
    
    init(
        request: @escaping (Demand) -> Void,
        control: @escaping (Control<ControlValue>) -> Void
    ) {
        self.request = request
        self.control = control
    }
    
    func cancel() { control(.finish) }
}

struct Publisher<Output, ControlValue, Failure: Error> {
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

struct Publication<Input, InputControl, InputFailure: Error, Output, OutputControl, OutputFailure: Error> {
    typealias DownstreamSubscriber = Subscriber<Output, OutputFailure>
    typealias UpstreamSubscriber = Subscriber<Input, InputFailure>

    typealias DownstreamSubscription = Subscription<OutputControl>
    typealias UpstreamSubscription = Subscription<InputControl>

    let hoist:     (DownstreamSubscriber) -> UpstreamSubscriber     // hoist subscriber
    let subscribe: (UpstreamSubscriber)   -> UpstreamSubscription   // subscribe
    let lower:     (UpstreamSubscription) -> DownstreamSubscription // lower subscription
}

extension Publication {
    func receive(subscriber: DownstreamSubscriber) -> DownstreamSubscription {
        subscriber |> hoist >>> subscribe >>> lower
    }
}

extension Publisher {
    var publication: Publication<Output, ControlValue, Failure,Output, ControlValue, Failure> {
        Publication(hoist: identity, subscribe: receive, lower: identity)
    }
}
