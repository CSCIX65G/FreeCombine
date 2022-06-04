//: [Previous](@previous)
import FreeCombine
import PlaygroundSupport
import _Concurrency

PlaygroundPage.current.needsIndefiniteExecution = true

var publisher1 = "01234567890123".asyncPublisher
var publisher2 = "abcdefghijklmnopqrstuvwxyz".asyncPublisher

Task {
    let c = await Merged(publisher1, publisher2)
    .map { $0.uppercased() }
    .sink({ result in
        switch result {
            case let .value(value):
                print(value)
                return .more
            case let .completion(.failure(error)):
                print("WTF? \(error)")
                return .done
            case .completion(.finished):
                print("Done")
                return .done
            case .completion(.cancelled):
                print("Done")
                return .done
        }
    })
    _ = try await c.value
}

//: [Next](@next)
