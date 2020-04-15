//
//  FreeCombine.swift
//  FreeCombine
//
//  Created by Van Simmons on 4/6/20.
//  Copyright © 2020 ComputeCycles, LLC. All rights reserved.
//

public enum Demand {
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

public enum Supply<Value, Failure> {
    case none
    case some(Value)
    case done
}

public struct Producer<Value, Failure> {
    let produce: (Demand) -> Supply<Value, Failure>
    let finish: () -> Void
}

public enum Completion<Failure: Error> {
    case finished
    case error(Failure)
}

public struct Subscriber<Input, Failure: Error> {
    let input: (Input) -> Demand
    let completion: (Completion<Failure>) -> Void
}

public enum Control<Value> {
    case finish
    case control(Value)
}

public class Subscription<ControlValue> {
    let request: (Demand) -> Void
    let control: (Control<ControlValue>) -> Void
    
    init(
        request: @escaping (Demand) -> Void,
        control: @escaping (Control<ControlValue>) -> Void
    ) {
        self.request = request
        self.control = control
    }
}

public extension Subscription {
    func cancel() { control(.finish) }
}

public struct Publisher<Input, InputControl, InputFailure: Error, Output, OutputControl, OutputFailure: Error> {
    public typealias DownstreamSubscriber = Subscriber<Output, OutputFailure>
    public typealias UpstreamSubscriber = Subscriber<Input, InputFailure>

    public typealias DownstreamSubscription = Subscription<OutputControl>
    public typealias UpstreamSubscription = Subscription<InputControl>

    let hoist:   (DownstreamSubscriber) -> UpstreamSubscriber     // hoist subscriber
    let convert: (UpstreamSubscriber)   -> UpstreamSubscription   // convert
    let lower:   (UpstreamSubscription) -> DownstreamSubscription // lower subscription
}

public extension Publisher {
    func receive(subscriber: DownstreamSubscriber) -> DownstreamSubscription {
        subscriber |> hoist >>> convert >>> lower
    }
}
