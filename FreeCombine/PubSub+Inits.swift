//
//  Subscriber+Inits.swift
//  FreeCombine
//
//  Created by Van Simmons on 4/13/20.
//  Copyright © 2020 ComputeCycles, LLC. All rights reserved.
//

extension Composer where Input == Output {
    func same(input: (Output) -> Demand) -> (Input) -> Demand {
        identity >>> recast
    }
}

extension Composer where InputFailure == OutputFailure {
    func same(completion: (Completion<OutputFailure>) -> Void) -> (Completion<InputFailure>) -> Void {
        identity >>> recast
    }
}

extension Composer where InputControl == OutputControl {
    func same(control: (Control<InputControl>) -> Void) -> (Control<OutputControl>) -> Void {
        identity >>> recast
    }
}

extension Composer {
    func same(request: (Demand) -> Void) -> (Demand) -> Void {
        identity >>> recast
    }
}

extension Subscriber {
    typealias InputTransform<New> =
        ((Input) -> Demand) -> (New) -> Demand
    typealias CompletionTransform<New: Error> =
        ((Completion<Failure>) -> Void) -> (Completion<New>) -> Void
    
    static func transform<UpstreamInput, UpstreamFailure: Error>(
        _ inputTransform: @escaping InputTransform<UpstreamInput>,
        _ completionTransform: @escaping CompletionTransform<UpstreamFailure>
    ) -> (Subscriber<Input, Failure>) -> Subscriber<UpstreamInput, UpstreamFailure> {
        { subscriber in
            Subscriber<UpstreamInput, UpstreamFailure>(
                input: subscriber.input |> inputTransform,
                completion: subscriber.completion |> completionTransform
            )
        }
    }
}

extension Subscription {
    typealias RequestTransform =
        ((Demand) -> Void) -> (Demand) -> Void
    typealias ControlTransform<New> =
        ((Control<ControlValue>) -> Void) -> (Control<New>) -> Void
    
    static func transform<UpstreamControlValue>(
        _ requestTransform: @escaping RequestTransform,
        _ controlTransform: @escaping ControlTransform<UpstreamControlValue>
    ) -> (Subscription<ControlValue>) -> Subscription<UpstreamControlValue> {
        { subscription in
            Subscription<UpstreamControlValue>(
                request: subscription.request |> requestTransform,
                control: subscription.control |> controlTransform
            )
        }
    }
}

extension Composer {
    init(
        input: @escaping ((Output) -> Demand) -> (Input) -> Demand,
        completion: @escaping ((Completion<OutputFailure>) -> Void) -> (Completion<InputFailure>) -> Void,
        subscribe: @escaping (Subscriber<Output, OutputFailure>) -> Subscription<OutputControl>,
        request: @escaping ((Demand) -> Void) -> (Demand) -> Void,
        control: @escaping ((Control<OutputControl>) -> Void) -> (Control<InputControl>) -> Void
    ) {
        self.composition = Self.Composition.publisherSubscriber(
            recast(Subscriber<Output, OutputFailure>.transform(input, completion)),
            recast(subscribe),
            recast(Subscription<OutputControl>.transform(request, control))
        )
    }
}
