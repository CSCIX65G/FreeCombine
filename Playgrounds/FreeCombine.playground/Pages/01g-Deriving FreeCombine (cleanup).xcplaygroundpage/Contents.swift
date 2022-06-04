//: [Previous](@previous)
import _Concurrency

enum Demand: Equatable {
    case more
    case done
}

enum Value<Supply, Failure: Error> {
   case value(Supply)
   case failure(Failure)
   case finished
}

protocol Publisher { // Publisher is just a thing that takes a callback
    associatedtype Supply
    associatedtype Failure: Error

    func receive(downstream: @escaping (Value<Supply, Failure>) async -> Demand) -> Task<Demand, Swift.Error>
}












struct Pub<Seq: Sequence> {
    typealias Supply = Int
    typealias Failure = Swift.Error

    var sequence: Seq
}

extension Pub: Publisher where Seq.Element == Supply {
    enum Error: Swift.Error {
        case cancelled
    }

    init(_ sequence: Seq) {
        self.sequence = sequence
    }

    func receive(downstream: @escaping (Value<Supply, Failure>) async -> Demand) -> Task<Demand, Swift.Error> {
        Task {
            print("publisher received subscriber")
            for i in sequence {
                guard await downstream(.value(i)) == .more else { break }
            }
            return await downstream(.finished)
        }
    }
}

import Foundation

let publisher: Pub = .init((0 ..< 100).shuffled()[0 ..< 50])

let t = publisher
    .receive(downstream: { input in
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

//: [Next](@next)
