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

protocol Subscribing {
    associatedtype SubscribingInput
    associatedtype SubscribingFailure: Error
    associatedtype SubscribingControl
    
    func receive(subscription: Subscription<SubscribingControl>) -> Void
}

protocol Publishing {
    associatedtype PublishingOutput
    associatedtype PublishingFailure: Error
    associatedtype PublishingOutputControl
        
    func receive<S>(subscriber: S) -> Void
    where S: Subscribing,
        S.SubscribingInput == PublishingOutput,
        S.SubscribingFailure == PublishingFailure,
        S.SubscribingControl == PublishingOutputControl
}

struct PubSub<Input, InputControl, InputFailure: Error, Output, OutputControl, OutputFailure: Error> {
    let liftInput: (@escaping (Output) -> Demand) -> (Input) -> Demand
    let liftCompletion: (@escaping (Completion<OutputFailure>) -> Void) -> (Completion<InputFailure>) -> Void
    let liftRequest: (@escaping (Demand) -> Void) -> (Demand) -> Void
    let liftControl: (@escaping (Control<InputControl>) -> Void) -> (Control<OutputControl>) -> Void
}

extension PubSub {
    static func output<Output, OutputFailure: Error>(
        _ output: @escaping (Output) -> Demand,
        _ completion: @escaping (Completion<OutputFailure>) -> Void,
        _ next: @escaping (Demand) -> Supply<Output, OutputFailure>
    ) -> (Demand) -> Void {
        { demand in
            guard demand.intValue > 0 else { return }
            var newDemand = demand
            while newDemand.intValue > 0 {
                let supply = next(newDemand)
                switch supply {
                case .none: return
                case .some(let value): newDemand = output(value)
                case .failure(let failure): completion(.error(failure)); return
                case .done: completion(.finished); return
                }
            }
        }
    }
}

typealias Subscriber<Input, InputFailure: Error> =
    PubSub<Input, Never, InputFailure, Never, Never, Never>

typealias Publisher<Output, OutputFailure: Error> =
    PubSub<Never, Never, Never, Output, Never, OutputFailure>

extension Publisher: Publishing {
    typealias PublishingOutput = Output
    typealias PublishingFailure = OutputFailure
    typealias PublishingOutputControl = OutputControl

    func receive<S>(subscriber: S)
        where S : Subscribing,
        Self.PublishingFailure == S.SubscribingFailure,
        Self.PublishingOutputControl == S.SubscribingControl,
        Self.PublishingOutput == S.SubscribingInput {
            subscriber.receive(subscription: Subscription(
                request: liftRequest(void),
                control: liftControl(void)
                )
            )
    }
    
    init(_ produce: @escaping (Demand) -> Supply<Output, OutputFailure>) {
        self.liftInput = const( {_ in .none } )
        self.liftCompletion = const(void)
        self.liftRequest = const(void)
        self.liftControl = const(void)
    }
}


//extension PublisherSubscriber {
//    func sink(
//        receiveCompletion: @escaping ((Completion<PublisherFailure>) -> Void) = { _ in },
//        receiveValue: @escaping ((PublisherOutput) -> Void)
//    ) {
//        receive(
//            subscriber: Subscriber<PublisherOutput, PublisherFailure>(
//                input: { input in receiveValue(input); return .unlimited },
//                completion: receiveCompletion
//            )
//        )
//        .request(.unlimited)
//    }
//}

//struct OriginatingPublisher<Output, Failure: Error>: Publisher {
//    typealias PublisherOutput = Output
//    typealias PublisherFailure = Failure
//    typealias Sub = Subscriber<PublisherOutput, PublisherFailure>
//    typealias Comp = Completion<PublisherFailure>
//
//    let request: (_ subscriber: Sub, _ demand: Demand ) -> Void
//    let completion: (_ subscriber: Sub, _ completion: Comp) -> Void
//
//    init(
//        request: @escaping (_ subscriber: Sub, _ demand: Demand ) -> Void,
//        completion: @escaping (_ subscriber: Sub, _ completion: Comp) -> Void
//    ) {
//        self.request = request
//        self.completion = completion
//    }
//
//    func receive(subscriber: Subscriber<Output, Failure>) -> Subscription<Failure> {
//        Subscription(request: curry(request)(subscriber), completion: curry(completion)(subscriber))
//    }
//}
