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
 You only have to say how much you want
 not what kind of thing you want. You can
 cancel anytime you want, which consists of indicating
 that you will never generate additional demand.
*/
public enum Demand {
    case none
    case max(Int)
    case unlimited
    case cancel

    var quantity: Int {
        switch self {
        case .none: return 0
        case .max(let val): return val
        case .unlimited: return Int.max
        case .cancel: return 0
        }
    }
}

/*:
 A Demand can be fulfilled with a Supply
 which can be either none, a value of the desired
 type, a failure to produce a value, or a notification
 that no future values can be forthcoming.
 
 Since Supply is a generic parameterized by
 two other types, you expect it to have two
 map functions (and it does, in another file).
*/
public enum Supply<Value, Failure: Error> {
    case none
    case value(Value)
    case failure(Failure)
    case finished
}

/*:
 These are our 2 basic types.  Everything we do in this package
 is simply writing functions that manipulate these supply and demand.
 Best of all, the manipulations that we want to do themselves
 come in only 4 basic types of functions which can then be composed
 using the 5 standard functions on Func.  So you _must_ understand
 how those function-returning-functions do their work.
 
 So diving into our function types...
 
 Ultimately, there must be a function which produces a Supply
 in response to a Demand.  We call such a function a Producer.
 */
public struct Producer<Value, Failure: Error> {
    public let call: (Demand) -> Supply<Value, Failure>
    public init(_ call: @escaping (Demand) -> Supply<Value, Failure>) {
        self.call = call
    }
}

/*:
 Since we have a function which can produce Supply in
 response to Demand, there must also be a function which
 consumes a Supply to satisfy a Demand.  We call
 such a function a Subscriber because it will not consume
 just one supply, but an entire series of them if supply
 is available.
 
 In a very human manner a Subscriber consuming some Supply
 can induce even more Demand which it provides as its function
 return type.
 
 This way of describing the combination of producing
 and subscribing means that you can compose Subscribers
 with Producers. This should be very intuitive since it is
 how all of economics actually works as well.
 
 But... You can only form a Subscriber AFTER you have a Producer,
 so the composition of the two functions must be a `contraMap`
 or `contraFlatMap` (i.e. you prepend the Producer to the Subscriber).
 In particular, since we can produce Supply in batches, we are
 going to want to use `contraFlatMap`, which means that
 we are going to need at least a `join` function on
 Subscriber as well.
 
 This last point is _very_ important to understand, it reveals
 a huge amount about what `contraFlatMap` actually _means_
 
 `contraFlatMap`ping a Subscriber with a Producer yields a
 function from Demand to Demand as you can verify:

     (Producer >>> Subscriber) -> (Demand) -> Demand

 (I use >>> here imprecisely since I haven't written an
 operator for `contraFlatMap` in the `join` form). Note that
 this operation erases the Supply type in the process.
 */
public struct Subscriber<Value, Failure: Error> {
    public let call: (Supply<Value, Failure>) -> Demand
    public init(_ call: @escaping (Supply<Value, Failure>) -> Demand) {
        self.call = call
    }
}

/*:
 A Subscription is a function which is its own independent source
 of Demand, so it doesn't care about the demand returned from
 a Subscriber.  Hence a Subscription is a function
 (Demand) -> Void which can be derived as follows:
 
     (Producer >>> Subscriber).map(void)
 
 erasing the Demand type in the process.  The second
 `init` below allows us to go straight from:
 `(Producer >>> Subscriber)` to `Subscription` in
 this manner
 */
public struct Subscription {
    public let call: (Demand) -> Void
    public init(_ call: @escaping (Demand) -> Void) {
        self.call = call
    }
    
    public init(_ f: Func<Demand, Demand>) {
        self.init(f.map(void).call)
    }
}

/*:
 Finally, we need some way of taking a Producer and a
 Subscriber and creating a Subscription.
 
 A Publisher is a curried function which combines a Producer
 and a Subscriber to yield a Subscription in the manner
 shown above.  I.e. it has the form:
 
     (Producer) -> (Subscriber) -> Subscription

 It can be initialized with a Producer (the first init below)
 or with a function (Subscriber) -> Subscription (the second
 init below) where the Producer has already been partially
 applied to the function.
 
 And as always, because Publisher is parameterized by multiple
 generic types, it too, has multiple forms of map.  Indeed
 it has a lot of functionality which
 allows us to chain Publishers together in all sorts of
 interesting ways.
 
 The majority of this library is given over to chaining
 Publishers in fact.
*/
public struct Publisher<Output, Failure: Error> {
    public let call: (Subscriber<Output, Failure>) -> Subscription
    
    public init(_ call: @escaping (Subscriber<Output, Failure>) -> Subscription) {
        self.call = call
    }
}
/*:
 All of FreeCombine is implemented as composition of the 2 basic value types
 using the 4 basic function types.  To reiterate, the value types are:
 
     Demand
     Supply (which as a genereric has map functions on it)
 
 and the function types (all represented as "call-as-function"
 Swift structs) are:
 
     Producer: (Demand) -> Supply
     Subscriber: (Supply) -> Demand
     Subscription: (Demand) -> Void (which is (Producer >>> Subscriber) ignoring output)
     Publisher: (Producer) -> (Subscriber) -> Subscription
 
 and we "combine" these elements using the basic functional
 programming elements of:
 
     map
     flatMap
     contraMap
     contraFlatMap
     dimap
 
 which are all the functions we defined on our Func struct.
 */

// The produce/consume loop
extension Subscriber {
    static func producerJoin(
        _ producer: Producer<Value, Failure>
    ) -> (Self) -> Self {
        let demandRef = Reference<Demand>(.max(1))
        return { downstreamSubscriber in
            return .init { supply in
                demandRef.value = downstreamSubscriber(supply)
                while demandRef.value.quantity > 0 {
                    let nextSupply = producer(demandRef.value)
                    switch nextSupply {
                    case .none:
                        return demandRef.value
                    case .value, .failure:
                        demandRef.value = downstreamSubscriber(nextSupply)
                    case .finished:
                        return downstreamSubscriber(nextSupply)
                    }
                }
                return demandRef.value
            }
        }
    }
}

extension Publisher {
    init(_ producer: Producer<Output, Failure>) {
        self.call = { subscriber in
            .init(subscriber.contraFlatMap(Subscriber.producerJoin(producer), producer.call))
        }
    }
}
