//
//  Channel+StateTask.swift
//  
//
//  Created by Van Simmons on 8/26/22.
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
public extension Channel {
    func stateTask<State>(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line,
        initialState: @escaping (Self) async -> State,
        reducer: Reducer<State, Element>
    ) async throws -> StateTask<State, Element> {
        var stateTask: StateTask<State, Element>!
        let _: Void = try await withResumption(function: function, file: file, line: line) { resumption in
            stateTask = .init(
                function: function,
                file: file,
                line: line,
                channel: self,
                onStartup: resumption,
                initialState: initialState,
                reducer: reducer
            )
        }
        return stateTask
    }

    func stateTask<State>(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line,
        onStartup: Resumption<Void>,
        initialState: @escaping (Self) async -> State,
        reducer: Reducer<State, Element>
    ) -> StateTask<State, Element> {
        .init(
            function: function,
            file: file,
            line: line,
            channel: self,
            onStartup: onStartup,
            initialState: initialState,
            reducer: reducer
        )
    }
}
