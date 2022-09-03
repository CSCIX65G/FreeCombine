//
//  And.swift
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
public enum AndInput<Left: Sendable, Right: Sendable> {
    enum Error: Swift.Error {
        case neither
        case left(Left)
        case right(Right)
    }
    case left(Left)
    case right(Right)
}

func andFold<Left, Right>(
    state: inout Result<(Left, Right), Swift.Error>,
    action: Result<(Int, AndInput<Left, Right>), Swift.Error>
) async -> Reducer<
    FoldState<AndInput<Left, Right>, (Left, Right)>,
    FoldState<AndInput<Left, Right>, (Left, Right)>.Action
>.Effect {
    switch action {
        case let .success((_, .left(left))):
            switch state {
                case .failure(AndInput<Left, Right>.Error.neither):
                    state = .failure(AndInput<Left, Right>.Error.left(left))
                    return .none
                case .failure(AndInput<Left, Right>.Error.right(let right)):
                    state = .success((left, right))
                    return .completion(.exit)
                default:
                    fatalError("already sent")
            }
        case let .success((_, .right(right))):
            switch state {
                case .failure(AndInput<Left, Right>.Error.neither):
                    state = .failure(AndInput<Left, Right>.Error.right(right))
                    return .none
                case .failure(AndInput<Left, Right>.Error.left(let left)):
                    state = .success((left, right))
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
    func and<Other>(
        _ other: Future<Other>
    ) -> Future<(Output, Other)> {
        Anded(self, other)
    }
}

public func Anded<Left, Right>(
    _ left: Future<Left>,
    _ right: Future<Right>
) -> Future<(Left, Right)> {
    and(left, right)
}

public func and<Left, Right>(
    _ left: Future<Left>,
    _ right: Future<Right>
) -> Future<(Left, Right)> {
    .init(
        initialState: FoldState<AndInput<Left, Right>, (Left, Right)>.create(
            initialValue: Result<(Left, Right), Swift.Error>.failure(AndInput<Left, Right>.Error.neither),
            fold: andFold,
            futures: [left.map(AndInput.left), right.map(AndInput.right)]
        ),
        buffering: .bufferingOldest(2),
        reducer: Reducer(
            reducer: FoldState<AndInput<Left, Right>, (Left, Right)>.reduce,
            disposer: FoldState<AndInput<Left, Right>, (Left, Right)>.dispose,
            finalizer: FoldState<AndInput<Left, Right>, (Left, Right)>.complete
        )
    )
}

public func and<A, B, C>(
    _ one: Future<A>,
    _ two: Future<B>,
    _ three: Future<C>
) -> Future<(A, B, C)> {
    and(and(one, two), three)
        .map { ($0.0.0, $0.0.1, $0.1) }
}

public func and<A, B, C, D>(
    _ one: Future<A>,
    _ two: Future<B>,
    _ three: Future<C>,
    _ four: Future<D>
) -> Future<(A, B, C, D)> {
    and(and(one, two), and(three, four))
        .map { ($0.0.0, $0.0.1, $0.1.0, $0.1.1) }
}

public func and<A, B, C, D, E>(
    _ one: Future<A>,
    _ two: Future<B>,
    _ three: Future<C>,
    _ four: Future<D>,
    _ five: Future<E>
) -> Future<(A, B, C, D, E)> {
    and(and(and(one, two), and(three, four)), five)
        .map { ($0.0.0.0, $0.0.0.1, $0.0.1.0, $0.0.1.1, $0.1) }
}

public func and<A, B, C, D, E, F>(
    _ one: Future<A>,
    _ two: Future<B>,
    _ three: Future<C>,
    _ four: Future<D>,
    _ five: Future<E>,
    _ six: Future<F>
) -> Future<(A, B, C, D, E, F)> {
    and(and(and(one, two), and(three, four)), and(five, six))
        .map { ($0.0.0.0, $0.0.0.1, $0.0.1.0, $0.0.1.1, $0.1.0, $0.1.1) }
}

public func and<A, B, C, D, E, F, G>(
    _ one: Future<A>,
    _ two: Future<B>,
    _ three: Future<C>,
    _ four: Future<D>,
    _ five: Future<E>,
    _ six: Future<F>,
    _ seven: Future<G>
) -> Future<(A, B, C, D, E, F, G)> {
    and(and(and(one, two), and(three, four)), and(and(five, six), seven))
        .map { ($0.0.0.0, $0.0.0.1, $0.0.1.0, $0.0.1.1, $0.1.0.0, $0.1.0.1, $0.1.1) }
}

public func and<A, B, C, D, E, F, G, H>(
    _ one: Future<A>,
    _ two: Future<B>,
    _ three: Future<C>,
    _ four: Future<D>,
    _ five: Future<E>,
    _ six: Future<F>,
    _ seven: Future<G>,
    _ eight: Future<H>
) -> Future<(A, B, C, D, E, F, G, H)> {
    and(and(and(one, two), and(three, four)), and(and(five, six), and(seven, eight)))
        .map { ($0.0.0.0, $0.0.0.1, $0.0.1.0, $0.0.1.1, $0.1.0.0, $0.1.0.1, $0.1.1.0, $0.1.1.1) }
}
