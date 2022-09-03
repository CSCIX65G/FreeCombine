//
//  Folded.swift
//  
//
//  Created by Van Simmons on 8/24/22.
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

//public func foldWithEventLoop<OtherValue>(
//    _ futures: [EventLoopFuture<OtherValue>],
//    with combiningFunction: @escaping @Sendable (Value, OtherValue, EventLoop) -> EventLoopFuture<Value>
//) -> EventLoopFuture<Value> {
//    func fold0(eventLoop: EventLoop) -> EventLoopFuture<Value> {
//        let body = futures.reduce(self) { (f1: EventLoopFuture<Value>, f2: EventLoopFuture<OtherValue>) -> EventLoopFuture<Value> in
//            let newFuture = f1.and(f2).flatMap { (args: (Value, OtherValue)) -> EventLoopFuture<Value> in
//                let (f1Value, f2Value) = args
//                self.eventLoop.assertInEventLoop()
//                return combiningFunction(f1Value, f2Value, eventLoop)
//            }
//            assert(newFuture.eventLoop === self.eventLoop)
//            return newFuture
//        }
//        return body
//    }
//
//    if self.eventLoop.inEventLoop {
//        return fold0(eventLoop: self.eventLoop)
//    } else {
//        let promise = self.eventLoop.makePromise(of: Value.self)
//        self.eventLoop.execute { [eventLoop = self.eventLoop] in
//            fold0(eventLoop: eventLoop).cascade(to: promise)
//        }
//        return promise.futureResult
//    }
//}
import Atomics

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
            return .completion(.failure(error))
    }
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


public func fold<Output, OtherValue>(
    initial: Future<Output>,
    over other: Future<OtherValue>,
    with combiningFunction: @escaping @Sendable (Output, OtherValue) async -> Future<Output>
) -> Future<Output> {
    initial.flatMap { outputValue in
        let otherResultRef: ValueRef<Result<OtherValue, Swift.Error>> = .init(value: .failure(FutureError.internalError))
        _ = await Cancellable<Cancellable<Void>> { await other { otherResult in
            otherResultRef.set(value: otherResult)
        } }.join().result
        guard case let .success(otherValue) = otherResultRef.value else {
            return Failed(Output.self, error: FutureError.internalError)
        }
        return await combiningFunction(outputValue, otherValue)
    }
}

public func fold<Output, OtherValue>(
    _ futures: [Future<OtherValue>],
    with combiningFunction: @escaping @Sendable (Output, OtherValue) async -> Future<Output>
) -> Future<Output> {
    return Failed(Output.self, error: FutureError.internalError)
}
