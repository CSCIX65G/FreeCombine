import FreeCombine

_ = Just(14).sink(
    receiveCompletion: { completion in print("Completed") },
    receiveValue: { value in
        guard value == 14 else { print("Incorrect value"); return }
        print("Success!")
    }
)
