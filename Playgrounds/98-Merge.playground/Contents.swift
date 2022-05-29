import FreeCombine
import Coroutine

import PlaygroundSupport
PlaygroundPage.current.needsIndefiniteExecution = true

var publisher1 = SequencePublisher("01234567890123")
var publisher2 = SequencePublisher("abcdefghijklmnopqrstuvwxyz")

Task {
_ = await merge(publisher1, publisher2)
    .map { $0.uppercased() }
    .subscribe { result in
        switch result {
            case let .value(value):
                print(value)
                return .more
            case let .failure(error):
                print("WTF? \(error)")
                return .done
            case .terminated:
                print("Done")
                return .done
        }
    }
}
