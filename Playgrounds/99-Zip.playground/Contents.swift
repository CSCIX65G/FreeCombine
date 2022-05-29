import FreeCombine
import Coroutine

import PlaygroundSupport
PlaygroundPage.current.needsIndefiniteExecution = true

var count = 0
var publisher1 = SequencePublisher(0 ... 100)
var publisher2 = SequencePublisher("abcdefghijklmnopqrstuvwxyz")

let cancellable = zip(publisher1, publisher2)
    .map { ($0.0 + 100, $0.1.uppercased()) }
    .sink { result in
        switch result {
            case .value:
                count += 1
            case let .failure(error):
                print("WTF? \(error)")
            case .terminated:
                print("Done")
        }
        return .more
    }

cancellable
