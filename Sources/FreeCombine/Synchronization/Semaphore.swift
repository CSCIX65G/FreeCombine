//
//  Semaphore.swift
//  
//
//  Created by Van Simmons on 4/24/22.
//
//  Copyright 2022, ComputeCycles, LLC
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//
public class Semaphore<State, Action> {
    public enum Error: Swift.Error {
        case complete
    }
    private let resumption: Resumption<State>
    private let reducer: (inout State, Action) -> Void

    private var state: State
    private var counter: Counter
    private var actions: SingleConsumerStack<Action> = .init()

    var count: Int { counter.count }

    public init(
        resumption: Resumption<State>,
        reducer: @escaping (inout State, Action) -> Void,
        initialState: State,
        count: Int
    ) {
        self.resumption = resumption
        self.reducer = reducer
        self.state = initialState
        self.counter = .init(count: count)
        if count == 0 { resumption.resume(returning: initialState) }
    }

    public func decrement(
        function: String = #function,
        file: String = #file,
        line: Int = #line,
        with action: Action
    ) -> Void {
        actions.push(action)
        switch counter.decrement() {
            case Int.min ..< 0:
                fatalError("Semaphore decremented after complete in \(function) @\(file):\(line)")
            case 1 ... Int.max:
                return
            default:
                while let prevAction = actions.pop() {
                    reducer(&state, prevAction)
                }
        }
        resumption.resume(returning: state)
    }
}
