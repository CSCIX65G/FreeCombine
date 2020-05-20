import FreeCombine

let p1 = Just(14)
    .map { $0 * 2 }

let c1 = p1.sink {
    switch $0 {
    case .value(let value):
        guard value == 28 else {
            print("Failed!")
            return
        }
        print("Value = \(value)")
    default:
        print("Completed")
    }
}

let p2 = PublishedSequence([1, 2, 3, 4, 5])
    .map { $0  * 2 }

let c2 = p2.sink {
    switch $0 {
    case .value(let value):
        print("Value = \(value)")
    default:
        print("Completed")
    }
}
