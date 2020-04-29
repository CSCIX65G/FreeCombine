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
 not what kind of thing you want.
*/
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
 that no future values can be forthcoming.
 
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
 The are our 3 basic types.  Everything we do in this package
 is simply writing functions that manipulate these types.
 Best of all the manipulations that we want to do themselves
 come in 3 basic types of functions which can then be composed
 using the 5 stand functions on Func.  So you _must_ understand
 how those function-returning-functions do.
 
 So diving into our function types...
 
 Ultimately, there must be a function which produces a Publication
 in response to a Request.  We call such a function a Producer.
 
 Like all the functions we will discuss which are parameterized
 by multiple generic types, producers have a family of interesting
 map functions, which we will explore in detail elsewhere in
 the library.
*/
public struct Producer<Value, Failure: Error> {
    public let call: (Request) -> Publication<Value, Failure>
    public init(_ call: @escaping (Request) -> Publication<Value, Failure>) {
        self.call = call
    }
}

/*:
 Since we have a function which can produce Publications in
 response to requests, there must also be a function which
 satisfies a Request by consuming a Publication.  We call
 such a function a Subscriber.
 
 In a very human manner a Subscriber consuming a publication
 can induce even more Demand which it provides as its function
 return type.
 
 This division of production and consumption means
 that you can compose Subscribers with Producers.
 This should be very intuitive since it is how all
 of economics actually works as well.
 
 But... You only get the Subscriber AFTER you have a producer,
 so the composition of the two functions must be a `contraMap`
 or `contraFlatMap` (i.e. you prepend the Producer to the Subscriber).
 In particular, since we can produce Publications in batches, we are
 going to want to use `contraFlatMap`, which means that
 we are going to need at least a `join` function on
 Subscriber as well.
 
 `contraFlatMap`ping a Subscriber with a Producer yields a
 function from Request to Demand as you can verify:

     (Producer >>> Subscriber) -> (Request) -> Demand

 (I use >>> here imprecisely since I haven't written an
 operator for `contraFlatMap` in the `join` form). Note that
 this operation erases the Publication type in the process.
 
 Also note that since Subscriber has two generic parameters
 like Publication, you expect it to have multiple forms
 of map, flatMap, contraMap and contraFlatMap. (And
 since we will need them it actually does, in another file).
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
 
 erasing the Demand type in the process.  The second
 `init` below allows us to go straight from:
 `(Producer >>> Subscriber)` to `Subscription` in
 this manner
 */
public struct Subscription {
    public let call: (Request) -> Void
    public init(_ call: @escaping (Request) -> Void) {
        self.call = call
    }
    
    public init(_ f: Func<Request, Demand>) {
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
 it has a generalized form of monadic functionality which
 allow us to chain Publishers together in all sorts of
 interesting ways.
 
 The majority of this library is given over to chaining
 Publishers in fact.
*/
public struct Publisher<Output, Failure: Error> {
    public let call: (Subscriber<Output, Failure>) -> Subscription
    
    init(_ producer: Producer<Output, Failure>) {
        self.call = { subscriber in
            .init(subscriber.contraFlatMap(Subscriber.producerJoin(producer), producer.call))
        }
    }

    public init(_ call: @escaping (Subscriber<Output, Failure>) -> Subscription) {
        self.call = call
    }
}
/*:
 All of FreeCombine is implemented as composition of the 3 basic value types
 using the 4 basic function types.  To reiterate, the value types are:
 
     Demand
     Request
     Publication
 
 and the function types (all represented as "call-as-function"
 Swift structs) are:
 
     Producer: (Request) -> Publication
     Subscriber: (Publication) -> Demand
     Subscription: (Request) -> Void
     Publisher: (Producer) -> (Subscriber) -> Subscription
 
 and we "combine" these elements using the basic functional
 programming elements of:
 
     map
     flatMap
     contraMap
     contraFlatMap
     dimap
 */
