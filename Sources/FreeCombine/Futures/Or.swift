//
//  File.swift
//  
//
//  Created by Van Simmons on 9/3/22.
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
public enum OrInput<Input: Sendable> {
    enum Error: Swift.Error {
        case none
    }
    case winner(Input)
}

func orFold<Input>(
    state: inout Result<Input, Swift.Error>,
    action: Result<(Int, OrInput<Input>), Swift.Error>
) async -> Reducer<
    FoldState<OrInput<Input>, Input>,
    FoldState<OrInput<Input>, Input>.Action
>.Effect {
    switch action {
        case let .success((_, .winner(input))):
            switch state {
                case .failure(OrInput<Input>.Error.none):
                    state = .success(input)
                    return .completion(.exit)
                default:
                    fatalError("already sent")
            }
        case let .failure(error):
            state = .failure(error)
            return .completion(.failure(error))
    }
}

public extension Future {
    func or(
        _ other: Future<Output>
    ) -> Future<Output> {
        Ored(self, other)
    }
}

public func Ored<Output>(
    _ left: Future<Output>,
    _ right: Future<Output>
) -> Future<Output> {
    or(left, right)
}

public func or<Input>(
    _ left: Future<Input>,
    _ right: Future<Input>
) -> Future<Input> {
    .init(
        initialState: FoldState<OrInput<Input>, Input>.create(
            initialValue: Result<Input, Swift.Error>.failure(OrInput<Input>.Error.none),
            fold: orFold,
            futures: [left.map(OrInput.winner), right.map(OrInput.winner)]
        ),
        buffering: .bufferingOldest(2),
        reducer: Reducer(
            reducer: FoldState<OrInput<Input>, Input>.reduce,
            disposer: FoldState<OrInput<Input>, Input>.dispose,
            finalizer: FoldState<OrInput<Input>, Input>.complete
        )
    )
}

public func or<Input, S: Sequence>(
    _ left: Future<Input>,
    _ others: S
) -> Future<Input> where S.Element == Future<Input> {
    .init(
        initialState: FoldState<OrInput<Input>, Input>.create(
            initialValue: Result<Input, Swift.Error>.failure(OrInput<Input>.Error.none),
            fold: orFold,
            futures: [left.map(OrInput.winner)] + others.map { $0.map(OrInput.winner) }
        ),
        buffering: .bufferingOldest(2),
        reducer: Reducer(
            reducer: FoldState<OrInput<Input>, Input>.reduce,
            disposer: FoldState<OrInput<Input>, Input>.dispose,
            finalizer: FoldState<OrInput<Input>, Input>.complete
        )
    )
}

public func or<Input>(
    _ left: Future<Input>,
    _ others: Future<Input>...
) -> Future<Input> {
    or(left, others)
}
