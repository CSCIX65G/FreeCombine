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
    
    var intValue: Int {
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
    case failure(Failure)
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

enum Control<Value> {
    case finish
    case control(Value)
}

class Subscription<Value> {
    let request: (Demand) -> Void
    let control: (Control<Value>) -> Void
    
    init(
        request: @escaping (Demand) -> Void,
        control: @escaping (Control<Value>) -> Void
    ) {
        self.request = request
        self.control = control
    }
    
    func cancel() { control(.finish) }
}

struct Subscriber<Input, Failure: Error, ControlValue> {
    let input: (Input) -> Demand
    let completion: (Completion<Failure>) -> Void
}

struct Composer<Input, InputControl, InputFailure: Error, Output, OutputControl, OutputFailure: Error> {
    typealias DownstreamSubscriber = Subscriber<Output, OutputFailure, OutputControl>
    typealias UpstreamSubscriber = Subscriber<Input, InputFailure, InputControl>

    typealias DownstreamSubscription = Subscription<OutputControl>
    typealias UpstreamSubscription = Subscription<InputControl>

    let liftSubscriber:  (DownstreamSubscriber) -> UpstreamSubscriber
    let subscribe: (DownstreamSubscriber, UpstreamSubscriber) -> UpstreamSubscription
    let lowerSubscription: (DownstreamSubscriber, UpstreamSubscription) -> DownstreamSubscription
    
    func receive(subscriber: DownstreamSubscriber) -> DownstreamSubscription {
        subscriber |>
            liftSubscriber
            >>> (subscriber |> curry(subscribe))
            >>> (subscriber |> curry(lowerSubscription))
    }
}
