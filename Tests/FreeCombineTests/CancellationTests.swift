//
//  CancellationTests.swift
//  
//
//  Created by Van Simmons on 5/15/22.
//

import XCTest
@testable import FreeCombine

class CancellationTests: XCTestCase {

    override func setUpWithError() throws { }

    override func tearDownWithError() throws { }

    func testSimpleZipCancellation() async throws {
        let expectation = await CheckedExpectation<Void>()
        let waiter = await CheckedExpectation<Void>()
        let startup = await CheckedExpectation<Void>()

        let publisher1 = (0 ... 100).asyncPublisher
        let publisher2 = "abcdefghijklmnopqrstuvwxyz".asyncPublisher

        let counter = Counter()
        let z1 = await zip(publisher1, publisher2)
            .map { ($0.0 + 100, $0.1.uppercased()) }
            .sink { (result: AsyncStream<(Int, String)>.Result) in
                switch result {
                    case .value:
                        let count = await counter.increment()
                        if count > 9 {
                            try await startup.complete()
                            try await waiter.value
                            return .more
                        }
                        if Task.isCancelled {
                            XCTFail("Got values after cancellation")
                            do { try await expectation.complete() }
                            catch { XCTFail("Failed to complete: \(error)") }
                            return .done
                        }
                    case let .completion(.failure(error)):
                        XCTFail("Got an error? \(error)")
                    case .completion(.finished):
                        XCTFail("Got to end of task that should have been cancelled")
                        do { try await expectation.complete() }
                        catch { XCTFail("Failed to complete: \(error)") }
                        return .done
                    case .completion(.cancelled):
                        try await expectation.complete()
                        return .done
                }
                return .more
            }

        try await startup.value
        z1.cancel()
        try await waiter.complete()

        do { try await FreeCombine.wait(for: expectation, timeout: 100_000_000) }
        catch {
            XCTFail("Timed out with count: \(await counter.count)")
        }
    }

    func testMultiZipCancellation() async throws {
        let expectation = await CheckedExpectation<Void>()
        let expectation2 = await CheckedExpectation<Void>()
        let waiter = await CheckedExpectation<Void>()
        let startup1 = await CheckedExpectation<Void>()
        let startup2 = await CheckedExpectation<Void>()

        let publisher1 = Unfolded(0 ... 100)
        let publisher2 = Unfolded("abcdefghijklmnopqrstuvwxyz")

        let counter1 = Counter()
        let counter2 = Counter()
        let zipped = zip(publisher1, publisher2)
            .map { ($0.0 + 100, $0.1.uppercased()) }

        let z1 = await zipped.sink({ result in
            switch result {
                case .value:
                    let count2 = await counter2.increment()
                    if (count2 == 1) {
                        try await startup1.complete()
                    }
                    return .more
                case let .completion(.failure(error)):
                    XCTFail("Got an error? \(error)")
                    return .done
                case .completion(.finished):
                    let count2 = await counter2.count
                    XCTAssertTrue(count2 == 26, "Incorrect count: \(count2)")
                    do { try await expectation2.complete() }
                    catch { XCTFail("Multiple terminations sent: \(error)") }
                    return .done
                case .completion(.cancelled):
                    XCTFail("Should not have cancelled")
                    try await expectation2.complete()
                    return .done
            }
        })

        let z2 = await zipped
            .sink({ result in
                switch result {
                    case .value:
                        let count1 = await counter1.increment()
                        if count1 == 10 {
                            try await startup2.complete()
                            try await waiter.value
                            return .more
                        }
                        if count1 > 10 {
                            XCTFail("Received values after cancellation")
                        }
                        return .more
                    case let .completion(.failure(error)):
                        XCTFail("Got an error? \(error)")
                        return .done
                    case .completion(.finished):
                        XCTFail("Got to end of task that should have been cancelled")
                        do {
                            try await expectation.complete()
                        }
                        catch { XCTFail("Multiple terminations sent: \(error)") }
                        return .done
                    case .completion(.cancelled):
                        try await expectation.complete()
                        return .done
                }
            })

        try await startup1.value
        try await startup2.value
        z2.cancel()
        try await waiter.complete()

        do {
            try await FreeCombine.wait(for: expectation, timeout: 100_000_000)
            try await FreeCombine.wait(for: expectation2, timeout: 100_000_000)
            let count1 = await counter1.count
            XCTAssert(count1 == 10, "Wrong number in z2: \(count1)")
        } catch {
            XCTFail("Timed out")
        }
        z1.cancel()
    }

    func testSimpleMergeCancellation() async throws {
        let expectation = await CheckedExpectation<Void>()
        let waiter = await CheckedExpectation<Void>()
        let startup = await CheckedExpectation<Void>()

        let publisher1 = "zyxwvutsrqponmlkjihgfedcba".asyncPublisher
        let publisher2 = "abcdefghijklmnopqrstuvwxyz".asyncPublisher

        let counter = Counter()
        let z1 = await merge(publishers: publisher1, publisher2)
            .map { $0.uppercased() }
            .sink { result in
                switch result {
                    case .value:
                        let count = await counter.increment()
                        if count > 9 {
                            try await startup.complete()
                            try await waiter.value
                        }
                        if count > 10 && Task.isCancelled {
                            XCTFail("Got values after cancellation")
                        }
                        return .more
                    case let .completion(.failure(error)):
                        XCTFail("Got an error? \(error)")
                        return .done
                    case .completion(.finished):
                        XCTFail("Got to end of task that should have been cancelled")
                        do { try await expectation.complete() }
                        catch { XCTFail("Failed to complete: \(error)") }
                        return .done
                    case .completion(.cancelled):
                        try await expectation.complete()
                        return .done
                }
            }

        try await startup.value
        z1.cancel()
        try await waiter.complete()

        do { try await FreeCombine.wait(for: expectation, timeout: 100_000_000) }
        catch { XCTFail("Timed out with count: \(await counter.count)") }
    }
}
