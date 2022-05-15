//
//  SequencePublisherTests.swift
//  
//
//  Created by Van Simmons on 5/15/22.
//

import XCTest
@testable import FreeCombine

class SequencePublisherTests: XCTestCase {

    override func setUpWithError() throws { }

    override func tearDownWithError() throws { }

    func testSimpleSequencePublisher() async throws {
        let expectation1 = await CheckedExpectation<Void>()
        let expectation2 = await CheckedExpectation<Void>()

        let sequencePublisher = SequencePublisher(0 ..< 10)

        let counter1 = Counter()
        _ = await sequencePublisher.sink { (result: AsyncStream<Int>.Result) in
            switch result {
                case .value:
                    await counter1.increment()
                    return .more
                case let .completion(.failure(error)):
                    XCTFail("Got an error? \(error)")
                    return .done
                case .completion(.finished):
                    let count = await counter1.count
                    guard count == 10 else {
                        XCTFail("Incorrect count: \(count) in subscription 1")
                        return .done
                    }
                    do { try await expectation1.complete() }
                    catch { XCTFail("Failed to complete with error: \(error)") }
                    return .done
            }
        }

        let counter2 = Counter()
        _ = await sequencePublisher.sink { (result: AsyncStream<Int>.Result) in
            switch result {
                case .value:
                    await counter2.increment()
                    return .more
                case let .completion(.failure(error)):
                    XCTFail("Got an error? \(error)")
                    return .done
                case .completion(.finished):
                    let count = await counter2.count
                    guard count == 10 else {
                        XCTFail("Incorrect count: \(count) in subscription 1")
                        return .done
                    }
                    do { try await expectation2.complete() }
                    catch { XCTFail("Failed to complete with error: \(error)") }
                    return .done
            }
        }

        do {
            try await FreeCombine.wait(for: expectation1, timeout: 1_000_000)
            try await FreeCombine.wait(for: expectation2, timeout: 1_000_000)
        } catch {
            XCTFail("Timed out")
        }
    }

    func testVariableSequencePublisher() async throws {
        let expectation1 = await CheckedExpectation<Void>()
        let expectation2 = await CheckedExpectation<Void>()

        let sequencePublisher = (0 ..< 10).asyncPublisher

        let counter1 = Counter()
        _ = await sequencePublisher.sink { (result: AsyncStream<Int>.Result) in
            switch result {
                case .value:
                    await counter1.increment()
                    return .more
                case let .completion(.failure(error)):
                    XCTFail("Got an error? \(error)")
                    return .done
                case .completion(.finished):
                    let count = await counter1.count
                    guard count == 10 else {
                        XCTFail("Incorrect count: \(count) in subscription 1")
                        return .done
                    }
                    do { try await expectation1.complete() }
                    catch { XCTFail("Failed to complete with error: \(error)") }
                    return .done
            }
        }

        let counter2 = Counter()
        _ = await sequencePublisher.sink { (result: AsyncStream<Int>.Result) in
            switch result {
                case .value:
                    await counter2.increment()
                    return .more
                case let .completion(.failure(error)):
                    XCTFail("Got an error? \(error)")
                    return .done
                case .completion(.finished):
                    let count = await counter2.count
                    guard count == 10 else {
                        XCTFail("Incorrect count: \(count) in subscription 1")
                        return .done
                    }
                    do { try await expectation2.complete() }
                    catch { XCTFail("Failed to complete with error: \(error)") }
                    return .done
            }
        }

        do {
            try await FreeCombine.wait(for: expectation1, timeout: 1_000_000)
            try await FreeCombine.wait(for: expectation2, timeout: 1_000_000)
        } catch {
            XCTFail("Timed out")
        }
    }

}
