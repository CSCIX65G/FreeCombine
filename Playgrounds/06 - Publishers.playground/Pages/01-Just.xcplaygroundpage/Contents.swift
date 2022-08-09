//: [Previous](@previous)

import Foundation
import FreeCombine
import _Concurrency

Task {
    let cancellation = await Just(14).sink { result in
        Swift.print(result)
        return .more
    }
    _ = await cancellation.result
}
//: [Next](@next)
