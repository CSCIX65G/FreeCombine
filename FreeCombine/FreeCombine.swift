//
//  FreeCombine.swift
//  FreeCombine
//
//  Created by Van Simmons on 4/6/20.
//  Copyright © 2020 ComputeCycles, LLC. All rights reserved.
//

/*:
 # Combine as the composition of functions
 
 In the beginning is Demand for some values.
*/
public enum Demand {
    case none
    case max(Int)
    case unlimited
    case last

    var quantity: Int {
        switch self {
        case .none: return 0
        case .max(let val): return val
        case .unlimited: return Int.max
        case .last: return 0
        }
    }
}

/*:
 You can wrap your demand for values in a Request
 that allows you to also say "I won't be making
 any further Requests"
*/
public enum Request {
    case demand(Demand)
    case cancel
}

/*:
 A Request can be fulfilled with a Publication
 which is either no value, a value of the desired
 type, a failure to produce a value, or a notification
 that no future values will be forthcoming.
 
 Since Publication is a generic parameterized by
 two other types, you expect it to have two
 map functions (and it does, in another file).
*/
public enum Publication<Value, Failure: Error> {
    case none
    case value(Value)
    case failure(Failure)
    case finished
}

/*:
 Ultimately, there must be a function which produces a Publication
 in response to a Request.  We call such a function a Producer.
*/
public struct Producer<Value, Failure: Error> {
    public let call: (Request) -> Publication<Value, Failure>
    public init(_ call: @escaping (Request) -> Publication<Value, Failure>) {
        self.call = call
    }
}

/*:
 There must also be a function which satisfies a Request
 by consuming a Publication.  We call such a function
 a Subscriber.  In a very human manner a Subscriber
 consuming a publication can cause even more Demand
 which it provides as its return type.
 
 This form means that you can compose Subscribers
 with Producers.  Since you only get the Subscriber
 AFTER you have a producer, the composition must be a
 `contraMap` or `contraFlatMap` (i.e. you prepend the
 Producer to the Subscriber). `contraMap`ping a
 Subscriber with a Producer yields a function
 from Request to Demand as you can verify:

     (Producer >>> Subscriber) -> (Request) -> Demand

 erasing the Publication type in the process.
 */
public struct Subscriber<Value, Failure: Error> {
    public let call: (Publication<Value, Failure>) -> Demand
    public init(_ call: @escaping (Publication<Value, Failure>) -> Demand) {
        self.call = call
    }
}

/*:
 A Subscription is a function which is its own independent source
 of Demand, so it doesn't care about the demand returned from
 a Subscriber.  Hence a Subscription is a function
 (Request) -> Void which can be derived as follows:
 
     (Producer >>> Subscriber).map(void)
 
 erasing the Demand type in the process
 */
public struct Subscription {
    public let call: (Request) -> Void
    public init(_ call: @escaping (Request) -> Void) {
        self.call = call
    }
}

/*:
 A Publisher is a curried function which combines a Producer
 and a Subscriber to yield a Subscription in the manner
 shown immediately above:
 
     (Producer) -> (Subscriber) -> Subscription

 It can be initialized with a Producer (the first init below)
 or with a function (Subscriber) -> Subscription (the second
 init below) where the Producer has already been partially
 applied to the entire function.
*/
public struct Publisher<Output, Failure: Error> {
    public let call: (Subscriber<Output, Failure>) -> Subscription
    
    init(_ producer: Producer<Output, Failure>) {
        self.call = { subscriber in
            .init(subscriber.contraFlatMap(Subscriber.join(producer), producer.call))
        }
    }

    public init(_ call: @escaping (Subscriber<Output, Failure>) -> Subscription) {
        self.call = call
    }
}
