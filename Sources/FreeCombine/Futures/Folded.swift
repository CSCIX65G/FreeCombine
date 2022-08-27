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

public enum Either<Left, Right> {
    case left(Left)
    case right(Right)
}

//public func first<Left, Right>(
//    of left: Future<Left>,
//    _ right: Future<Right>
//) async throws -> (Either<Left, Right>, Either<Cancellable<Left>, Cancellable<Right>>) {
//    let first: ManagedAtomic<Int> = .init(0)
//    var buffer: (Either<Left, Right>, Either<Cancellable<Left>, Cancellable<Right>>)!
//    do {
//        let _: Void = try await withResumption { resumption in
//            leftCancellable = Cancellable<Cancellable<Void>> { await left { leftResult in
//                do {
//
//                    let (success, _) = first.compareExchange(expected: 0, desired: 1, ordering: .sequentiallyConsistent)
//                    guard success else { return }
//                    resumption.resume()
//                } catch { }
//            } }.join()
//            rightCancellable = Cancellable<Cancellable<Void>> { await right { rightResult in
//                do {
//                    try rightResultRef.set(value: rightResult)
//                    let (success, _) = first.compareExchange(expected: 0, desired: 2, ordering: .sequentiallyConsistent)
//                    guard success else { return }
//                    resumption.resume()
//                } catch { }
//            } }.join()
//        }
//    } catch {
//
//    }
//}

public func and<Left,Right>(
    _ left: Future<Left>,
    _ right: Future<Right>
) -> Future<(Left, Right)> {
    .init { continuation, downstream in
        Cancellable<Void> {
            let first: ManagedAtomic<Int> = .init(0)
            let leftResultRef: ValueRef<Result<Left, Swift.Error>> = .init(value: .failure(FutureError.internalError))
            let rightResultRef: ValueRef<Result<Right, Swift.Error>> = .init(value: .failure(FutureError.internalError))
            var leftCancellable: Cancellable<Void>!
            var rightCancellable: Cancellable<Void>!
            continuation.resume()
            do {
                let _: Void = try await withResumption { resumption in
                    leftCancellable = Cancellable<Cancellable<Void>> { await left { leftResult in
                        do {
                            try leftResultRef.set(value: leftResult)
                            let (success, _) = first.compareExchange(expected: 0, desired: 1, ordering: .sequentiallyConsistent)
                            guard success else { return }
                            resumption.resume()
                        } catch { }
                    } }.join()
                    rightCancellable = Cancellable<Cancellable<Void>> { await right { rightResult in
                        do {
                            try rightResultRef.set(value: rightResult)
                            let (success, _) = first.compareExchange(expected: 0, desired: 2, ordering: .sequentiallyConsistent)
                            guard success else { return }
                            resumption.resume()
                        } catch { }
                    } }.join()
                }
            } catch {

            }
            switch first.load(ordering: .sequentiallyConsistent) {
                case 1:
                    switch leftResultRef.value {
                        case let .success(leftValue):
                            _ = await rightCancellable.result
                            switch rightResultRef.value {
                                case let .success(rightValue):
                                    try await downstream(.success((leftValue, rightValue)))
                                case let .failure(error):
                                    try await downstream(.failure(error))
                            }
                        case let .failure(error):
                            rightCancellable.cancel()
                            try await downstream(.failure(error))
                    }
                case 2:
                    switch rightResultRef.value {
                        case let .success(rightValue):
                            _ = await leftCancellable.result
                            switch leftResultRef.value {
                                case let .success(leftValue):
                                    try await downstream(.success((leftValue, rightValue)))
                                case let .failure(error):
                                    try await downstream(.failure(error))
                            }
                        case let .failure(error):
                            rightCancellable.cancel()
                            try await downstream(.failure(error))
                    }
                default:
                    fatalError("Inconsistent state and-ing futures")
            }
        }
    }
}


public func fold<Output, OtherValue>(
    initial: Future<Output>,
    over other: Future<OtherValue>,
    with combiningFunction: @escaping @Sendable (Output, OtherValue) async -> Future<Output>
) -> Future<Output> {
    initial.flatMap { outputValue in
        let otherResultRef: ValueRef<Result<OtherValue, Swift.Error>> = .init(value: .failure(FutureError.internalError))
        _ = await Cancellable<Cancellable<Void>> { await other { otherResult in
            do { try otherResultRef.set(value: otherResult) } catch { }
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