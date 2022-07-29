import PlaygroundSupport
PlaygroundPage.current.needsIndefiniteExecution = true
import FreeCombine

let numbers = [5, 4, 3, 2, 1, 0]
let romanNumeralDict: [Int : String] = [1:"I", 2:"II", 3:"III", 4:"IV", 5:"V"]
let cancellable = await numbers.asyncPublisher
    .map { romanNumeralDict[$0] ?? "(unknown)" }
    .sink({ result in
        switch result {
            case .value(let value):
                Swift.print("\(value)", terminator: " ")
                return .more
            case .completion(let completion):
                Swift.print("\n\(completion)")
                return .done
        }
    })

await cancellable.result
