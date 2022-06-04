//: [Previous](@previous)

enum Demand: Equatable {
    case more
//    case notRightNow
    case done
}

enum Value<Supply, Failure: Error> {
   case value(Supply)
   case failure(Failure)
   case finished
}

//protocol Subscription {
//    func request(_ demand: Demand) -> Void
//}

//protocol Subscriber { //Subscriber is just a souped-up callback
//    associatedtype Supply
//    associatedtype Failure: Error
//    func receive(_ input: Value<Supply, Failure>) async -> Demand
////    func receive(completion: Completion<Failure>) -> Void
////    func receive(subscription: Subscription) -> Void
//}

// Continuation: ((A) -> R) -> R
protocol Publisher { // Publisher is just a thing that takes a callback
    associatedtype Supply
    associatedtype Failure: Error

    func receive(downstream: @escaping (Value<Supply, Failure>) async -> Demand) async -> Demand
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

    func receive(downstream: @escaping (Value<Supply, Failure>) async -> Demand) async -> Demand {
        print("publisher received subscriber")
        for i in sequence {
            guard await downstream(.value(i)) == .more else { break }
        }
        return await downstream(.finished)
    }
}

import Foundation

let publisher: Pub = .init((0 ..< 100).shuffled()[0 ..< 50])

Task {
    await publisher.receive(downstream: { input in
        print("subscriber receiving: \(input)")
        guard case let .value(value) = input, value != 57 else {
            print("subscriber replying .done")
            return .done
        }
        if (0 ..< 4).randomElement() == 0 {
            print("waiting a bit...")
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }
        print("subscriber replying .more")
        return .more
    })
}

//: [Next](@next)
