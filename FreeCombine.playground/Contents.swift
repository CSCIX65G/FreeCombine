import FreeCombine

let p = Just(14)
    .map { $0 * 2 }

let c = p.sink {
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

