//: [Previous](@previous)

import FreeCombine
import PlaygroundSupport
PlaygroundPage.current.needsIndefiniteExecution = true

var count = 0
var publisher1 = (0 ... 100).asyncPublisher
var publisher2 = "abcdefghijklmnopqrstuvwxyz".asyncPublisher

let cancellable = Zipped(publisher1, publisher2)
    .map { ($0.0 + 100, $0.1.uppercased()) }
    .sink(onStartup: .none) { result in
        switch result {
            case let .value(value):
                print(value)
                count += 1
            case let .completion(.failure(error)):
                print("WTF? \(error)")
            case .completion(.finished):
                print("Done")
            case .completion(.cancelled):
                print("Cancelled")
        }
        return .more
    }

cancellable

//: [Next](@next)
