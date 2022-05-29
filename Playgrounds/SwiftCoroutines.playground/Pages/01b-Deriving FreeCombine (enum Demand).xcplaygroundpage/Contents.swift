//: [Previous](@previous)

enum Demand: Equatable {
    case more
    case notRightNow
    case done
}

enum Completion<Failure: Error> {
   case failure(Failure)
   case finished
}

protocol Subscription {
    func request(_ demand: Demand) -> Void
}

protocol Subscriber { //Subscriber is just a souped-up callback
    associatedtype Supply
    associatedtype Failure: Error
    func receive(_ input: Supply) -> Demand // objectDidUdpateWith:
    func receive(completion: Completion<Failure>) -> Void // We're done
    func receive(subscription: Subscription) -> Void
}

protocol Publisher { // Publisher is just a thing that takes a callback
    associatedtype Supply
    associatedtype Failure: Error
    func receive<S: Subscriber>(subscriber: S) -> Void  // setDelegate
        where S.Supply == Supply, S.Failure == Failure
}

struct Script<S: Subscriber>: Subscription where S.Supply == Int {
    var iterator: AnyIterator<Int>
    var subscriber: S
    init(iterator: AnyIterator<Int>, subscriber: S) {
        self.iterator = iterator
        self.subscriber = subscriber
    }
    func request(_ demand: Demand) {
        guard demand == .more else { return }
        print("\nsubscription received request: \(demand)")
        while let value = iterator.next() {
            print("subscription sending \(value)")
            switch subscriber.receive(value) {
                case .more: continue
                case .notRightNow: return
                case .done:
                    while iterator.next() != nil { }
                    print("subscription terminating")
                    return
            }
        }
        print("subscription sending complete")
        subscriber.receive(completion: .finished)
    }

}

struct P: Publisher {
    typealias Supply = Int
    typealias Failure = Never

    var iterator: AnyIterator<Int>

    init<S: Sequence>(_ sequence: S)
    where S.Element == Int {
        self.iterator = .init(sequence.makeIterator())
    }

    func receive<S>(subscriber: S) where S : Subscriber, Never == S.Failure, Int == S.Supply {
        print("publisher received subscriber")
        let subscription = Script(iterator: iterator, subscriber: subscriber)
        subscriber.receive(subscription: subscription)
        subscription.request(.more)
    }
}

class Scribe: Subscriber {
    typealias Supply = Int
    typealias Failure = Never
    var subscription: Subscription?
    var canReceive = true
    private var currentValue: Int? = .none

    func receive(_ input: Int) -> Demand {
        guard canReceive else {
            currentValue = .none
            return .done
        }
        print("subscriber receiving: \(input)")
        guard input != 57 else {
            print("subscriber replying done")
            canReceive = false
            currentValue = 57
            return .done
        }
        let reply: Demand = (0 ..< 4).randomElement() == 0 ? .notRightNow : .more
//        let reply: Demand = .notRightNow
        currentValue = input
        print("subscriber replying: \(reply)")
        return reply
    }

    func receive(completion: Completion<Never>) {
        canReceive = false
        currentValue = .none
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
    script.request(.more)
}

//: [Next](@next)
