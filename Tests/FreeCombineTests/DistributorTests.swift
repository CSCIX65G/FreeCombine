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
        let channel = Channel<DistributorState<Int>.Action>.init(buffering: .bufferingOldest(1))
        var distributor = DistributorState(channel: channel, currentValue: 13, nextKey: 0, downstreams: [:])

        do {
            try await distributor.reduce(action: .receive(.value(15), .none))
            XCTAssert(distributor.currentValue == 15, "Did not set value")
        } catch {
            XCTFail("Failed with: \(error)")
        }
    }

    func testSimpleSubscribe() async throws {
        let channel = Channel<DistributorState<Int>.Action>.init(buffering: .bufferingOldest(1))
        let downstream: @Sendable (AsyncStream<Int>.Result) async throws -> Demand = { result in
            switch result {
                case .value:
                    return .more
                case .completion:
                    return .done
            }
        }

        let _: Void = await withUnsafeContinuation { c in
            Task {
                let _: Task<Demand, Swift.Error> = try await withUnsafeThrowingContinuation { taskC in
                    Task {
                        do {
                            var distributor = DistributorState(channel: channel, currentValue: 13, nextKey: 0, downstreams: [:])
                            XCTAssert(distributor.repeaters.count == 0, "Incorrect number of repeaters = \(distributor.repeaters.count)")
                            try await distributor.reduce(action: .subscribe(downstream, c, taskC))
                            XCTAssert(distributor.repeaters.count == 1, "Incorrect number of repeaters = \(distributor.repeaters.count)")
                        } catch {
                            XCTFail("Caught: \(error)")
                        }
                    }
                }
            }
        }
    }

    func testSimpleSubscribeAndSend() async throws {
        let counter = Counter()
        let expectation1: CheckedExpectation<Void> = await .init()
        let channel = Channel<DistributorState<Int>.Action>.init(buffering: .bufferingOldest(1))
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

        let _: Void = await withUnsafeContinuation { c in
            Task {
                let _: Task<Demand, Swift.Error> = try await withUnsafeThrowingContinuation { taskC in
                    Task {
                        do {
                            var distributor = DistributorState(channel: channel, currentValue: 13, nextKey: 0, downstreams: [:])
                            XCTAssert(distributor.repeaters.count == 0, "Incorrect number of repeaters = \(distributor.repeaters.count)")
                            try await distributor.reduce(action: .subscribe(downstream1, .none, .none))
                            XCTAssert(distributor.repeaters.count == 1, "Incorrect number of repeaters = \(distributor.repeaters.count)")
                            try await distributor.reduce(action: .subscribe(downstream2, .none, taskC))
                            XCTAssert(distributor.repeaters.count == 2, "Incorrect number of repeaters = \(distributor.repeaters.count)")
                            let count1 = await counter.count
                            XCTAssert(count1 == 2, "Incorrect number of sends: \(count1)")
                            try await distributor.reduce(action: .receive(.value(15), .none))
                            let count2 = await counter.count
                            XCTAssert(count2 == 4, "Incorrect number of sends: \(count2)")
                            try await distributor.reduce(action: .receive(.completion(.finished), c))
                            XCTAssert(distributor.repeaters.count == 0, "Incorrect number of repeaters = \(distributor.repeaters.count)")
                        } catch {
                            XCTFail("Caught: \(error)")
                        }
                    }
                }
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
        catch {
            XCTFail("Timed out")
        }
    }
}
