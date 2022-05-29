//: [Previous](@previous)

enum Demand: Equatable {
    case more
//    case notRightNow
    case done
}

enum Completion<Failure: Error> {
   case failure(Failure)
   case finished
}

//protocol Subscription {
//    func request(_ demand: Demand) -> Void
//}

protocol Subscriber { //Subscriber is just a souped-up callback
    associatedtype Supply
    associatedtype Failure: Error
    func receive(_ input: Supply) async -> Demand // objectDidUdpateWith:
    func receive(completion: Completion<Failure>) -> Void // We're done
//    func receive(subscription: Subscription) -> Void
}

protocol Publisher { // Publisher is just a thing that takes a callback
    associatedtype Supply
    associatedtype Failure: Error
    func receive<S: Subscriber>(subscriber: S) async -> Void  // setDelegate
        where S.Supply == Supply, S.Failure == Failure
}

//struct Script<S: Subscriber> where S.Supply == Int {
//    var iterator: AnyIterator<Int>
//    var subscriber: S
//    init(iterator: AnyIterator<Int>, subscriber: S) {
//        self.iterator = iterator
//        self.subscriber = subscriber
//    }
//    func request(_ demand: Demand) {
//        guard demand == .more else { return }
//        print("\nsubscription received request: \(demand)")
//        while let value = iterator.next() {
//            print("subscription sending \(value)")
//            switch subscriber.receive(value) {
//                case .more: continue
//                case .notRightNow: return
//                case .done:
//                    while iterator.next() != nil { }
//                    print("subscription terminating")
//                    return
//            }
//        }
//        print("subscription sending complete")
//        subscriber.receive(completion: .finished)
//    }
//
//}
import _Concurrency
struct Pub<Seq: Sequence> {
    typealias Supply = Int
    typealias Failure = Never

    var sequence: Seq
}
extension Pub: Publisher where Seq.Element == Supply {
    init(_ sequence: Seq) {
        self.sequence = sequence
    }

    func receive<S: Subscriber>(subscriber: S) async -> Void where S.Supply == Supply, S.Failure == Failure {
        print("publisher received subscriber")
        for i in sequence {
            guard await subscriber.receive(i) == .more else { break }
        }
    }
}

class Sub: Subscriber {
    typealias Supply = Int
    typealias Failure = Never

    func receive(_ input: Int) async -> Demand {
        print("subscriber receiving: \(input)")
        guard input != 57 else {
            print("subscriber replying .done")
            return .done
        }
        if (0 ..< 4).randomElement() == 0 {
            print("waiting a bit...")
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }
        print("subscriber replying .more")
        return .more
    }

    func receive(completion: Completion<Never>) {
        print("subscriber received complete")
    }
}

import Foundation

let subscriber: Sub = .init()
let publisher: Pub = .init((0 ..< 100).shuffled()[0 ..< 50])

Task {
    await publisher.receive(subscriber: subscriber)
}

//: [Next](@next)
