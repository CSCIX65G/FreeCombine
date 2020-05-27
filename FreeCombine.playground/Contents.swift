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

let c2 = [1, 2, 3]
    .publisher
    .map { $0 * 2 }
    .map { Double($0) }
    .map { "\($0)" }
    .sink {
        switch $0 {
        case .value(let value):
            print("Value = \(value)")
        default:
            print("Completed")
        }
    }
