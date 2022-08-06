//: [Previous](@previous)
import PlaygroundSupport
PlaygroundPage.current.needsIndefiniteExecution = true

import FreeCombine

let counter = Counter()
var publisher1 = (0 ... 100).asyncPublisher
var publisher2 = "abcdefghijklmnopqrstuvwxyz".asyncPublisher

@Sendable func zipSink(_ result: AsyncStream<(Int, String)>.Result) async -> Demand {
    switch result {
        case let .value(value):
            print(value)
            await counter.increment()
        case let .completion(.failure(error)):
            print("WTF? \(error)")
        case .completion(.finished):
            print("Done")
        case .completion(.cancelled):
            print("Cancelled")
    }
    return .more
}

let cancellable = await Zipped(publisher1, publisher2)
    .map { ($0.0 + 100, $0.1.uppercased()) }
    .sink(zipSink)

let count = await counter.count
await cancellable.result

//: [Next](@next)
