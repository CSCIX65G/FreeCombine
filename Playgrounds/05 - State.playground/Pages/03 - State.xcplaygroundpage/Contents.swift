//: [Previous](@previous)

struct Effect<Action> {
    private let _append: (Self, Self) -> Self
    init(append: @escaping (Self, Self) -> Self) {
        _append = append
    }
    func append(_ other: Self) -> Self {
        _append(self, other)
    }
}

struct Reducer<State, Action> {
    let reduce: (inout State, Action) -> Effect<Action>
    func callAsFunction(_ state: inout State, _ action: Action) -> Effect<Action> {
        reduce(&state, action)
    }
}

class Store<State, Action> {
    private var state: State
    private var effect: Effect<Action>
    private let reducer: Reducer<State, Action>

    init(
        state: State,
        effect: Effect<Action>,
        reducer: Reducer<State, Action>
    ) {
        self.state = state
        self.effect = effect
        self.reducer = reducer
    }

    func reduce(_ action: Action) -> State {
        effect = effect.append(reducer(&state, action))
        return state
    }
}


//: [Next](@next)
