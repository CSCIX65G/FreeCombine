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
 cancel anytime you want.
*/
public enum Demand {
    case none
    case max(Int)
    case unlimited
    case cancel
}
/*:
 A Demand can be fulfilled with a Supply
 which can be either none, a value of the desired
 type, a failure to produce a value, or a notification
 that no future values can be forthcoming.
 
 Since Supply is a generic value parameterized by
 two other types, you expect it to have two
 map functions (and it does, elsewhere).
*/
public enum Supply<Value, Failure: Error> {
    case none
    case value(Value)
    case failure(Failure)
    case finished
}
/*:
 These are our 2 basic types.  Everything we do in this package
 is simply writing functions that manipulate supply and demand instances.
 Best of all, the manipulations that we want to do
 come in only 4 basic types of functions which can then be composed
 using only the standard functions on Func.
 So if you understand how to combine all these function-returning-functions
 you understand how Combine does its work.
 
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
 just one value of the supply, but an entire series of them
 until the demand is sated, as long as supply is available.
 
 In a very human manner a Subscriber consuming some Supply
 can induce even more Demand which it provides as its function
 return type.
 
 This way of describing the combination of producing
 and subscribing means that you can compose Subscribers
 with Producers. This should be very intuitive since it is
 how all of economics actually works as well.
 
 Composing a producer with a subscriber looks like this:
 
     (Demand) -> Supply >>> (Supply) -> Demand
 
 to yield:
 
     (Demand) -> Demand
 
 But... You can only form a Subscriber AFTER you have a Producer,
 so the composition of the two functions must be a `contraMap`
 or `contraFlatMap` (i.e. you have to prepend the Producer
 to the Subscriber).
 
 In particular, since we can produce Supply in batches, we are
 going to want to use `contraFlatMap`, which means that
 we are going to need at least one `join` function on
 Subscriber as well.
 
 This last point is _very_ important to understand, it reveals
 a huge amount about what `contraFlatMap` actually _means_
 
 `contraFlatMap`ping a Subscriber with a Producer yields a
 function from Demand to Demand as above:

     (Subscriber.contraFlatMap(Producer)) -> (Demand) -> Demand
 
 with the output function looping until either
 demand is sated or supply is exhausted.

 Note that this operation erases the Supply type in the process.
 
 So here's what Subscriber looks like, it's just the
 inverse of Producer:
 */
public struct Subscriber<Value, Failure: Error> {
    public let call: (Supply<Value, Failure>) -> Demand
    public init(_ call: @escaping (Supply<Value, Failure>) -> Demand) {
        self.call = call
    }
}
/*:
 Here we've constructed a new subscriber from the
 pairing of a producer and another subscriber.
 This "outer" subscriber receives a supply to kick things off
 and calls the inner subscriber and the producer repeatedly
 until either:

 1. the inner subscriber is satiated or
 2. the producer is exhausted.
 
 We need the outer subscriber so that we can iterate on the
 inner one. And _that_ is the key insight of contraFlatMap,
 not just in this case, but in all cases.  ContraFlatMap
 allows you to call a function (A) -> B multiple times while
 wrapped in context that also has signature (A) -> B, you
 just need an A to kick things off.
 
 Note that this is the dual of flatMap on a function.  In
 that case however we are given a function (B) -> C which
 already wraps another function (B) -> C which it can call
 multiple times.  This outer function just needs a B to
 kick things off.
 
 This sort of contraMap action is at the heart of
 Functional Reactive Programming (FRP).  In that model
 of writing applications, the values being passed
 through the functions are events which represent
 things that have occurred and data moves through
 applications in chains composed by contraMapping.
 
 So lets look closely at the signature of the
 satiate function.  If we curry it, it looks like this:
 
  (Producer) -> (Subscriber) -> Subscriber
 
 That last bit is telling.  It is precisely
 the signature of a `join` as used in a `contraFlatMap`
 of Subscriber. And that's something we'll be taking
 advantage of repeatedly below so keep it in mind.
 Let's move on to Subscriptions.
 
 A Subscription is a function which is its own independent source
 of demand, so it doesn't care about the demand returned from
 a Subscriber.  Hence a Subscription is a function
 (Demand) -> Void which can be derived as follows:
 
     (Subscriber.contraFlatMap(Producer)).map(void)
 
 erasing the Demand return type in the process.  The second
 `init` below allows us to go straight from:
 `(Subscriber.contraFlatMap(Producer))` to `Subscription` in
 this manner
 */
public struct Subscription {
    public let call: (Demand) -> Void
    
    public init(_ call: @escaping (Demand) -> Void) {
        self.call = call
    }
}
/*:
 Finally, we need some way of taking a Producer and a
 Subscriber and creating a Subscription.
 
 A Publisher is a curried function which combines a Producer
 and a Subscriber to yield a Subscription in precisely the manner
 shown above.  I.e. it has the form:
 
     (Producer) -> (Subscriber) -> Subscription

 That is to say that unlike Producer and Subscriber,
 Publisher is a higher-order function.  It accepts functions
 as input and produces functions as output.  (Remember,
 Producer, Subscriber and Subscription are themselves all
 functions).
 
 A Publisher can be initialized with a Producer (i a separate init below)
 or directly with a function (Subscriber) -> Subscription.
 This is a critical point.  There are several ways of preparing
 a Publisher, but the all _must_ end at:
 
     (Subscriber) -> Subscription
 
 In fact, most of this library is actually composed of functions
 of the form:
 
     (Publisher) -> (Subscriber) -> Subscription
 
 where a Publisher is created by "chaining" it onto another
 Publisher.  The forms that this can take are what make
 this technique so powerful.
 
 And as always, because Publisher is parameterized by
 generic types, it too, has multiple forms of map.  Which
 we will explore in detail.
*/
public struct Publisher<Output, Failure: Error> {
    public let call: (Subscriber<Output, Failure>) -> Subscription
    
    public init(
        _ call: @escaping (Subscriber<Output, Failure>) -> Subscription
    ) {
        self.call = call
    }
}
