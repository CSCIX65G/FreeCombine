//
//  DistributorTests.swift
//  
//
//  Created by Van Simmons on 5/14/22.
//

import XCTest
@testable import FreeCombine

class DistributorTests: XCTestCase {

    override func setUpWithError() throws { }

    override func tearDownWithError() throws { }

    func testSimpleReceiveValue() async throws {
        var distributor = DistributorState(currentValue: 13, nextKey: 0, downstreams: [:])

        do {
            _ = try await distributor.reduce(action: .receive(.value(15), .none))
            XCTAssert(distributor.currentValue == 15, "Did not set value")
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
        let demand: Demand = await withUnsafeContinuation { c in
            t = Task {
                let cancellable: Cancellable<Demand> = try await withUnsafeThrowingContinuation { taskC in
                    Task {
                        do {
                            var distributor = DistributorState(currentValue: 13, nextKey: 0, downstreams: [:])
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
    }

    func testSimpleSubscribeAndSend() async throws {
        let counter = Counter()
        let expectation1: CheckedExpectation<Void> = await .init()
        let downstream1: @Sendable (AsyncStream<Int>.Result) async throws -> Demand = { result in
            switch result {
                case .value:
                    await counter.increment()
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

        let expectation2: CheckedExpectation<Void> = await .init()
        let downstream2: @Sendable (AsyncStream<Int>.Result) async throws -> Demand = { result in
            switch result {
                case .value:
                    await counter.increment()
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

        var t: Task<Void, Swift.Error>!
        let _: Void = await withUnsafeContinuation { c in
            t = Task {
                let cancellable: Cancellable<Demand> = try await withUnsafeThrowingContinuation { taskC in
                    Task {
                        do {
                            var distributor = DistributorState(currentValue: 13, nextKey: 0, downstreams: [:])
                            XCTAssert(distributor.repeaters.count == 0, "Incorrect number of repeaters = \(distributor.repeaters.count)")
                            _ = try await distributor.reduce(action: .subscribe(downstream1, .none))
                            XCTAssert(distributor.repeaters.count == 1, "Incorrect number of repeaters = \(distributor.repeaters.count)")
                            _ = try await distributor.reduce(action: .subscribe(downstream2, taskC))
                            XCTAssert(distributor.repeaters.count == 2, "Incorrect number of repeaters = \(distributor.repeaters.count)")
                            let count1 = await counter.count
                            XCTAssert(count1 == 2, "Incorrect number of sends: \(count1)")
                            _ = try await distributor.reduce(action: .receive(.value(15), .none))
                            let count2 = await counter.count
                            XCTAssert(count2 == 4, "Incorrect number of sends: \(count2)")
                            _ = try await distributor.reduce(action: .receive(.completion(.finished), c))
                            XCTAssert(distributor.repeaters.count == 0, "Incorrect number of repeaters = \(distributor.repeaters.count)")
                        } catch {
                            XCTFail("Caught: \(error)")
                        }
                    }
                }
                cancellable.cancel()
                _ = try await cancellable.value
                c.resume()
            }
        }
        do {
            try await FreeCombine.wait(
                for: [expectation1, expectation2],
                timeout: 100_000_000,
                reducing: (),
                with: { _, _ in }
            )
        }
        catch { XCTFail("Timed out") }
        do {
            _ = try await t.value
        }
        catch { XCTFail("Should have completed") }
    }
}
