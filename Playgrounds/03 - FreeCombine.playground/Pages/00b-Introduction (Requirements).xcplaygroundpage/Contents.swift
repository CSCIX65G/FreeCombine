//: [Previous](@previous)

/*:
 Combine is a generalization of callbacks.  It provides support for the following callback features
 that many (most?) hand-rolled implementations of callbacks do not:

 1. Multiple invocation - hence Completion has a `.finished` case
 2. Error handling - hence Completion has a `.failure(Failure)` case
 3. Cancellation - hence Subscription meets the Cancellable protocol
 4. Backpressure - hence a Subscriber can request with Demand via a Subscription and return Demand from `receive(_ value:)`
 5. Asynchronous dispatch - when a Publisher receives a demand it may fulfill the demand at any point in the future
 6. Multiplexing - Subjects are 'push` rather than `pull` and can emit supply to subscribers regardless of demand
 */


//: [Next](@next)
