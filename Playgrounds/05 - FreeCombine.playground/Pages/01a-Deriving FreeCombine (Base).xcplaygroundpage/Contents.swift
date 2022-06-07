//: [Previous](@previous)

struct Demand {
    private var quantity: Int
    private init(quantity: Int) { self.quantity = quantity }
}

enum Completion<Failure: Error> {
   case failure(Failure)
   case finished
}

protocol Subscription {
    func request(_ demand: Demand) -> Void
}

protocol Subscriber {
    associatedtype Input
    associatedtype Failure: Error
    func receive(_ input: Input) -> Demand
    func receive(completion: Completion<Failure>) -> Void
    func receive(subscription: Subscription) -> Void
}

protocol Publisher {
    associatedtype Output
    associatedtype Failure: Error

    func receive<S: Subscriber>(subscriber: S) -> Void
        where S.Input == Output, S.Failure == Failure
}







extension Demand: Equatable, Comparable {
    public static var unlimited: Demand { .init(quantity: Int.max) }
    public static var none: Demand { .init(quantity: 0) }
    public static func max(_ anInt: Int) -> Demand { .init(quantity: anInt) }
    public static func ==(_ aDemand: Demand, _ anInt: Int) -> Bool { aDemand.quantity == anInt }
    public static func ==(_ anInt: Int, _ aDemand: Demand) -> Bool { aDemand.quantity == anInt }
    static func < (lhs: Demand, rhs: Demand) -> Bool { lhs.quantity < rhs.quantity }
    static func -= (_ demand: inout Demand, _ otherDemand: Demand) -> Void { demand.quantity -= otherDemand.quantity }
    static func -= (_ demand: inout Demand, _ anInt: Int) -> Void { demand.quantity -= anInt }
    static func += (_ demand: inout Demand, _ otherDemand: Demand) -> Void { demand.quantity += otherDemand.quantity }
    static func += (_ demand: inout Demand, _ anInt: Int) -> Void { demand.quantity += anInt }
}











class Script<S: Subscriber>: Subscription where S.Input == Int {
    var iterator: AnyIterator<Int>
    var subscriber: S
    var currentDemand: Demand = .none
    init(iterator: AnyIterator<Int>, subscriber: S) {
        self.iterator = iterator
        self.subscriber = subscriber
    }
    func request(_ demand: Demand) {
        guard demand != .none else { return }
        currentDemand += demand
        print("\nsubscription received request: \(demand), currentDemand = \(currentDemand)")
        while .none < currentDemand {
            if let value = iterator.next() {
                print("subscription sending \(value)")
                currentDemand += subscriber.receive(value)
                currentDemand -= 1
            } else {
                print("subscription sending complete")
                subscriber.receive(completion: .finished)
                currentDemand = .none
            }
        }
    }
}




struct P: Publisher {
    typealias Output = Int
    typealias Failure = Never

    var iterator: AnyIterator<Int>

    init<S: Sequence>(_ sequence: S)
    where S.Element == Int {
        self.iterator = .init(sequence.makeIterator())
    }

    func receive<S>(subscriber: S) where S : Subscriber, Never == S.Failure, Int == S.Input {
        print("publisher received subscriber")
        let subscription = Script(iterator: iterator, subscriber: subscriber)
        subscriber.receive(subscription: subscription)
        subscription.request(.max(1))
    }
}











class Scribe: Subscriber {
    typealias Supply = Int
    typealias Failure = Never
    var subscription: Subscription?
    var canReceive = true

    func receive(_ input: Int) -> Demand {
        guard canReceive else {
            return .none
        }
        print("subscriber receiving: \(input)")
        guard input != 57 else {
            print("subscriber replying done")
            canReceive = false
            return .none
        }
        let reply: Demand = (0 ..< 4).randomElement() == 0 ? .none : .max(1)
        print("subscriber replying: \(reply)")
        return reply
    }

    func receive(completion: Completion<Never>) {
        canReceive = false
        print("subscriber received complete")
    }

    func receive(subscription: Subscription) {
        print("subscriber received subscription")
        self.subscription = subscription
    }
}

import Foundation

let subscriber: Scribe = .init()
let publisher: P = .init((0 ..< 100).shuffled()[0 ..< 50])

publisher.receive(subscriber: subscriber)

let script = subscriber.subscription!

while subscriber.canReceive {
    print("waiting a bit...")
    usleep(1_000_000)
    script.request(.max(1))
}

//: [Next](@next)
