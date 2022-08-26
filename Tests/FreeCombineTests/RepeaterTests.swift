//
//  RepeaterTests.swift
//  
//
//  Created by Van Simmons on 5/13/22.
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
import XCTest
@testable import FreeCombine

class RepeaterTests: XCTestCase {

    override func setUpWithError() throws { }

    override func tearDownWithError() throws { }

    func testSimpleRepeater() async throws {
        let expectation = await Expectation<Void>()
        let downstream: @Sendable (AsyncStream<Int>.Result) async throws -> Demand = { result in
            switch result {
                case .value:
                    return .more
                case .completion:
                    try await expectation.complete()
                    return .done
            }
        }
        let nextKey = 1
        let _: Void = try await withResumption { resumption in
            Task {
                let repeaterState = DistributorRepeaterState(id: nextKey, downstream: downstream)
                let repeater: StateTask<DistributorRepeaterState<Int, Int>, DistributorRepeaterState<Int, Int>.Action> = .init(
                    channel: .init(buffering: .bufferingOldest(1)),
                    initialState: {_ in repeaterState },
                    onStartup: resumption,
                    reducer: Reducer(reducer: DistributorRepeaterState.reduce)
                )
                try await withResumption { (completedResumption: Resumption<[Int]>) in
                    let semaphore = Semaphore.init(
                        resumption: completedResumption,
                        reducer: { (completedIds: inout [Int], action: RepeatedAction<Int>) in
                            guard case let .repeated(id, .done) = action else { return }
                            completedIds.append(id)
                        },
                        initialState: [Int](),
                        count: 1
                    )
                    let queueStatus = repeater.send(.repeat(.value(14), semaphore))
                    guard case .enqueued = queueStatus else {
                        XCTFail("Internal failure in Repeater reducer processing key, queueStatus: \(queueStatus)")
                        return
                    }
                }.forEach { key in XCTFail("should not have key") }

                try await withResumption { (completedResumption: Resumption<[Int]>) in
                    let semaphore = Semaphore.init(
                        resumption: completedResumption,
                        reducer: { (completedIds: inout [Int], action: RepeatedAction<Int>) in
                            guard case let .repeated(id, .done) = action else { return }
                            completedIds.append(id)
                        },
                        initialState: [Int](),
                        count: 1
                    )
                    let queueStatus = repeater.send(.repeat(.value(15), semaphore))
                    guard case .enqueued = queueStatus else {
                        XCTFail("Internal failure in Repeater reducer processing key, queueStatus: \(queueStatus)")
                        return
                    }
                }.forEach { key in  XCTFail("should not have key") }

                try await withResumption { (completedResumption: Resumption<[Int]>) in
                    let semaphore = Semaphore.init(
                        resumption: completedResumption,
                        reducer: { (completedIds: inout [Int], action: RepeatedAction<Int>) in
                            guard case let .repeated(id, .done) = action else { return }
                            completedIds.append(id)
                        },
                        initialState: [Int](),
                        count: 1
                    )

                    let queueStatus = repeater.send(.repeat(.completion(.finished), semaphore))
                    guard case .enqueued = queueStatus else {
                        XCTFail("Internal failure in Repeater reducer processing key, queueStatus: \(queueStatus)")
                        return
                    }
                }.forEach { _ in () }
                _ = await repeater.cancellable.cancelAndAwaitResult()
            }
        }
        do {
            try await FreeCombine.wait(for: expectation, timeout: 10_000_000)
        } catch {
            XCTFail("Timed out")
        }
    }
}
