//
//  ReducingSemaphore.swift
//  
//
//  Created by Van Simmons on 4/24/22.
//
public actor ReducingSemaphore<State, Action> {
    public enum Error: Swift.Error {
        case complete
    }
    let continuation: UnsafeContinuation<State, Never>
    let reducer: (State, Action) -> State

    var state: State
    var count: Int

    public init(
        continuation: UnsafeContinuation<State, Never>,
        reducer: @escaping (State, Action) -> State,
        initialState: State,
        count: Int
    ) {
        self.continuation = continuation
        self.reducer = reducer
        self.state = initialState
        self.count = count
    }

    public func decrement(with action: Action, file: String = #file, line: Int = #line) -> Void {
        guard count > 0 else {
            fatalError("Semaphore decremented after complete @\(file):\(line)")
        }
        count -= 1
        state = reducer(state, action)
        if count == 0 {
            continuation.resume(returning: state)
        }
    }

    public func increment(with action: Action, file: String = #file, line: Int = #line) -> Void {
        guard count > 0 else {
            fatalError("Semaphore incremented after complete @\(file):\(line)")
        }
        count += 1
        state = reducer(state, action)
    }
}
