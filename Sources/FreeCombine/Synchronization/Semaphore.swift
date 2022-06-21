//
//  Semaphore.swift
//  
//
//  Created by Van Simmons on 4/24/22.
//
public actor Semaphore<State, Action> {
    public enum Error: Swift.Error {
        case complete
    }
    private let resumption: Resumption<State>
    private let reducer: (inout State, Action) -> Void

    private var state: State
    private var count: Int

    public init(
        resumption: Resumption<State>,
        reducer: @escaping (inout State, Action) -> Void,
        initialState: State,
        count: Int
    ) {
        self.resumption = resumption
        self.reducer = reducer
        self.state = initialState
        self.count = count
        if count == 0 { resumption.resume(returning: initialState) }
    }

    public func decrement(with action: Action, function: String = #function, file: String = #file, line: Int = #line) -> Void {
        guard count > 0 else {
            fatalError("Semaphore decremented after complete in \(function) @\(file):\(line)")
        }
        count -= 1
        reducer(&state, action)
        if count == 0 {
            resumption.resume(returning: state)
        }
    }

    public func increment(with action: Action, function: String = #function, file: String = #file, line: Int = #line) -> Void {
        guard count > 0 else {
            fatalError("Semaphore incremented after complete in \(function) @\(file):\(line)")
        }
        count += 1
        reducer(&state, action)
    }
}
