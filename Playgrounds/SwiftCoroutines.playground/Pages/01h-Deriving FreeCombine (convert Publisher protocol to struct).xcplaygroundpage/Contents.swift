//: [Previous](@previous)

import _Concurrency

enum Demand: Equatable {
    case more
    case done
}

enum Value<Supply> {
    case value(Supply)
    case failure(Swift.Error)
    case finished
}

public struct Publisher<Output> {
    private let call: (@escaping (Value<Output>) async -> Demand) -> Task<Demand, Swift.Error>
    init(
        _ call: @escaping (@escaping (Value<Output>) async -> Demand) -> Task<Demand, Swift.Error>
    ) {
        self.call = call
    }
}

extension Publisher {
    public enum Error: Swift.Error, CaseIterable, Equatable {
        case cancelled
    }
    func callAsFunction(_ downstream: @escaping (Value<Output>) async -> Demand) -> Task<Demand, Swift.Error> {
        call(downstream)
    }
}

extension Publisher {
    init<S: Sequence>(
        _ sequence: S
    ) where S.Element == Output {
        self = .init { downstream in
            return .init {
                guard !Task.isCancelled else { return .done }
                for a in sequence {
                    guard !Task.isCancelled else { return .done }
                    guard await downstream(.value(a)) == .more else { return .done }
                }
                guard !Task.isCancelled else { return .done }
                return await downstream(.finished)
            }
        }
    }
}

let publisher: Publisher<Int> = .init((0 ..< 100).shuffled()[0 ..< 50])

let t = publisher { input in
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
}

//: [Next](@next)
