//
//  DistributorTests.swift
//  
//
//  Created by Van Simmons on 5/14/22.
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

class DistributorTests: XCTestCase {

    override func setUpWithError() throws { }

    override func tearDownWithError() throws { }

    func testSimpleReceiveValue() async throws {
        do {
            let _: Int = try await withResumption { resumption in
                Task {
                    var distributor = DistributorState(
                        currentValue: 13,
                        nextKey: 0,
                        downstreams: [:]
                    )
                    _ = try await distributor.reduce(action: .receive(.value(15), resumption))
                    XCTAssert(distributor.currentValue == 15, "Did not set value")
                }
            }
        } catch {
            XCTFail("Failed with: \(error)")
        }
    }

    func testSimpleSubscribe() async throws {
        let downstream: @Sendable (AsyncStream<Int>.Result) async throws -> Demand = { result in
            switch result {
                case .value:
                    return .more
                case .completion:
                    return .done
            }
        }

        var t: Task<Void, Swift.Error>!
        do {
            let demand: Demand = try await withResumption { c in
                t = Task {
                    let cancellable: Cancellable<Demand> = try await withResumption { taskC in
                        Task {
                            do {
                                var distributor = DistributorState(
                                    currentValue: 13,
                                    nextKey: 0,
                                    downstreams: [:]
                                )
                                XCTAssert(distributor.repeaters.count == 0, "Incorrect number of repeaters = \(distributor.repeaters.count)")
                                _ = try await distributor.reduce(action: .subscribe(downstream, taskC))
                                XCTAssert(distributor.repeaters.count == 1, "Incorrect number of repeaters = \(distributor.repeaters.count)")
                            } catch {
                                XCTFail("Caught: \(error)")
                            }
                        }
                    }
                    cancellable.cancel()
                    let d = try await cancellable.value
                    c.resume(returning: d)
                }
            }
            do {
                _ = try await t.value
                XCTAssert(demand == .more, "incorrect demand")
            }
            catch {
                XCTFail("Should have completed")
            }
        } catch {
            XCTFail("Resumption failed")
        }
    }

    func testSimpleSubscribeAndSend() async throws {
        let counter = Counter()
        let expectation1: Expectation<Void> = await .init()
        let downstream1: @Sendable (AsyncStream<Int>.Result) async throws -> Demand = { result in
            switch result {
                case .value:
                    counter.increment()
                    return .more
                case let .completion(completion):
                    guard case Completion.finished = completion else {
                        XCTFail("Did not receive clean completion")
                        return .done
                    }
                    try await expectation1.complete()
                    return .done
            }
        }

        let expectation2: Expectation<Void> = await .init()
        let downstream2: @Sendable (AsyncStream<Int>.Result) async throws -> Demand = { result in
            switch result {
                case .value:
                    counter.increment()
                    return .more
                case let .completion(completion):
                    guard case Completion.finished = completion else {
                        XCTFail("Did not receive clean completion")
                        return .done
                    }
                    try await expectation2.complete()
                    return .done
            }
        }

        let taskSync = await Expectation<Void>()
        var t: Task<Void, Swift.Error>!
        let distributorValue = ValueRef(
            value: DistributorState(currentValue: 13, nextKey: 0, downstreams: [:])
        )
        do { let _: Int = try await withResumption { c in
            t = Task {
                let cancellable1: Cancellable<Demand> = try await withResumption { taskC in
                    Task {
                        do {
                            var distributor = distributorValue.value
                            XCTAssert(distributor.repeaters.count == 0, "Incorrect number of repeaters = \(distributor.repeaters.count)")
                            _ = try await distributor.reduce(action: .subscribe(downstream1, taskC))
                            distributorValue.set(value: distributor)
                            _ = try await taskSync.complete()
                        } catch {
                            XCTFail("Caught: \(error)")
                        }
                    }
                }
                let cancellable2: Cancellable<Demand> = try await withResumption { taskC in
                    Task {
                        do {
                            _ = try await taskSync.value
                            var distributor = distributorValue.value
                            XCTAssert(distributor.repeaters.count == 1, "Incorrect number of repeaters = \(distributor.repeaters.count)")
                            _ = try await distributor.reduce(action: .subscribe(downstream2, taskC))
                            XCTAssert(distributor.repeaters.count == 2, "Incorrect number of repeaters = \(distributor.repeaters.count)")
                            let count1 = counter.count
                            XCTAssert(count1 == 2, "Incorrect number of sends: \(count1)")
                            distributorValue.set(value: distributor)
                            distributor = try await withResumption { distResumption in
                                Task {
                                    let _: Int = try await withResumption({ resumption in
                                        Task {
                                            var distributor = distributorValue.value
                                            _ = try await distributor.reduce(action: .receive(.value(15), resumption))
                                            distResumption.resume(returning: distributor)
                                        }
                                    })
                                }
                            }
                            let count2 = counter.count
                            XCTAssert(count2 == 4, "Incorrect number of sends: \(count2)")
                            _ = try await distributor.reduce(action: .receive(.completion(.finished), c))
                            XCTAssert(distributor.repeaters.count == 0, "Incorrect number of repeaters = \(distributor.repeaters.count)")
                            distributorValue.set(value: distributor)
                        } catch {
                            XCTFail("Caught: \(error)")
                        }
                    }
                }
                do {
                    _ = try await cancellable1.value
                    _ = try await cancellable2.value
                } catch {
                    XCTFail("Failed to complete tasks")
                }
            }
        } } catch {
            XCTFail("Resumption threw")
        }
        do {
            _ = try await t.value
        }
        catch {
            XCTFail("Should have completed")
        }
    }
}
