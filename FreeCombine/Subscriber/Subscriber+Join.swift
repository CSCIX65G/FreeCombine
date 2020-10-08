//
//  Subscriber+Join.swift
//  FreeCombine
//
//  Created by Van Simmons on 5/26/20.
//  Copyright © 2020 ComputeCycles, LLC. All rights reserved.
//
/*:
 To get a feel for why this is a contraFlatMap,
 let's see what a function which would implement
 the satiate/exhaust loop for a subscriber/producer
 pair might look like.  Note that the Supply<Value, Failure>
 types have to match for the pairing to work.
 
 We need to either satiate the demand
 or exhaust the supply.
 */
extension Subscriber {
    static func satiateOrExhaust(
        from producer: Producer<Value, Failure>,
        into subscriber: Subscriber<Value, Failure>
    ) -> Subscriber<Value, Failure> {
        func consume(_ supply: Supply<Value, Failure>) -> Demand {
            let demand = subscriber(supply)
            guard demand.unsatisfied else { return demand }
            let nextSupply = producer(demand)
            switch nextSupply {
                case .none: return demand
                case .failure, .finished: return subscriber(nextSupply)
                case .value: return consume(nextSupply)
            }
        }
        return .init(consume)
    }
}
/*:
 ### A little philosophy
 
 To do anything we need to connect our Producer type to our
 Subscriber type.  Subscriber is a function:
 
 (Supply) -> Demand
 
 Producer is a function:
 
 (Demand) -> Supply
 
 Clearly the two functions compose, the question is which way?
 I.e. do I want to end up with a function of (Demand) -> Demand
 or of (Supply) -> Supply.  Which comes first the chicken or the
 egg?
 
 In this, as in economics, Demand precedes Supply and
 is fed Supply which arises to satiate it, so
 we want to prepend our Producer function to our Subscriber
 function. Prepending says immediately that we will need
 to contraMap the Producer function onto the Subscriber
 function.
 
 There's one added wrinkle: we want to repeatedly
 call producer, feeding its output to the subscriber until
 either the producer can't produce anymore or the subscriber
 responds with no further demand.  Making multiple calls
 is precisely why `contraFlatMap` exists.
 
 Look closely at the signature of `contraFlatMap`
 
 func contraFlatMap<C>(
 _ join:  @escaping (Self) -> Self,
 _ transform:@escaping (C) -> A
 ) -> Func<C, B>
 
 That join at the beginning is a little weird. `contraFlatMap`
 allows us to wrap self (the subscriber function) in another
 function of the same signature which calls the self (inner
 function) as many times as necessary to deliver the values.
 This is precisely what we want.
 
 We will form an outer `join` function which when given
 an initial value will repeatedly call the producer
 and subscriber functions until one of them is exhausted.
 
 Here's what such a join function looks like.
 */
extension Subscriber {
    static func join(
        _ producer: Producer<Value, Failure>
    ) -> (Subscriber<Value, Failure>) -> Subscriber<Value, Failure> {
        curry(satiateOrExhaust)(producer)
    }
}
/*:
 Summarizing:
 
 All of FreeCombine is implemented
 as composition of the 2 basic value types
 using the 3 basic function types
 and one higher-order function type.
 
 To reiterate, the value types are:
 
 Demand
 Supply
 
 and the base function types (all represented as "call-as-function"
 Swift structs) are:
 
 Producer: (Demand) -> Supply
 Subscriber: (Supply) -> Demand
 Subscription: (Demand) -> Void
 
 The higher-order function type is Publisher:
 
 Publisher: (Subscriber) -> Subscription = ((Supply) -> Demand) -> ((Demand) -> Void)
 
 which takes on two even higher higher-order forms when curried
 as:
 
 (Producer)  -> (Subscriber) -> Subscription  and
 (Subscriber contraFlatMap) -> (Publisher) -> (Subscription contraFlatMap) -> (Subscriber) -> Subscription
 
 these forms are not given names but much of the library is
 given over to them.
 
 We "Combine" these elements using the basic functional
 programming elements as follows:
 
 On Supply we use:
 map
 
 And on Subscriber and Subscription we use:
 contraFlatMap
 
 And on Publisher we use:
 dimap
 
 to form a plethora of more complex forms
 
 These are all functions we defined on our Func struct.
 
 And this is _all_ we need to create something like
 Combine or RxSwift.
 */
/*:
 This is the curried form I described above:
 
 (Producer) -> (Subscriber) -> Subscriber
 
 Where the meaning of this particular `join` is described
 by the `satiateOrExhaust` function.  This is the pattern we will
 adopt throughout.  We'll name a `join` and then see what
 we can do with it in the context of Publisher chaining.
 
 Note that the inner function is kicked off with a Supply.
 In FreeCombine this will always be the case.  Subscribers
 are functions (Supply) -> Demand, so `contraFlatMap`ping them
 will always require us to preserve that signature and
 our joins will have the form:
 
 (Subscriber) -> Subscriber
 
 or in detail:
 
 ((Supply) -> Demand) -> ((Supply) -> Demand)
 
 This supply is then provided to the downstreamSubscriber
 to obtain more demand.  If there is positive demand,
 we ask the producer for more supply. If there is any,
 we in turn feed the supply to the downstream.  Lather,
 rinse, repeat until one is exhausted.
 
 Now we can call `contraFlatMap` on the subscriber, rolling
 the producer up in our join function (remember the signature):

 func contraFlatMap<Demand>(
 _ join:  @escaping ((Supply) -> Demand) -> ((Supply) -> Demand),
 _ transform:@escaping (Demand) -> Supply
 ) -> Func<Demand, Demand>


 and passing the producer itself as the transform function.
 */
