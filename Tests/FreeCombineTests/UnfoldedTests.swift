//
//  SequencePublisherTests.swift
//  
//
//  Created by Van Simmons on 5/15/22.
//

import XCTest
@testable import FreeCombine

class UnfoldedTests: XCTestCase {

    override func setUpWithError() throws { }

    override func tearDownWithError() throws { }

    func testSimpleUnfolded() async throws {
        let expectation1 = await Expectation<Void>()
        let expectation2 = await Expectation<Void>()

        let unfolded = Unfolded(0 ..< 10)

        let counter1 = Counter()
        let u1 = await unfolded.sink { (result: AsyncStream<Int>.Result) in
            switch result {
                case .value:
                    counter1.increment()
                    return .more
                case let .completion(.failure(error)):
                    XCTFail("Got an error? \(error)")
                    return .done
                case .completion(.finished):
                    let count = counter1.count
                    guard count == 10 else {
                        XCTFail("Incorrect count: \(count) in subscription 1")
                        return .done
                    }
                    do { try await expectation1.complete() }
                    catch { XCTFail("Failed to complete with error: \(error)") }
                    return .done
                case .completion(.cancelled):
                    XCTFail("Should not have cancelled")
                    return .done
            }
        }

        let counter2 = Counter()
        let u2 = await unfolded.sink { (result: AsyncStream<Int>.Result) in
            switch result {
                case .value:
                    counter2.increment()
                    return .more
                case let .completion(.failure(error)):
                    XCTFail("Got an error? \(error)")
                    return .done
                case .completion(.finished):
                    let count = counter2.count
                    guard count == 10 else {
                        XCTFail("Incorrect count: \(count) in subscription 1")
                        return .done
                    }
                    do { try await expectation2.complete() }
                    catch { XCTFail("Failed to complete with error: \(error)") }
                    return .done
                case .completion(.cancelled):
                    XCTFail("Should not have cancelled")
                    return .done
            }
        }

        do {
            try await FreeCombine.wait(for: expectation1, timeout: 10_000_000)
            try await FreeCombine.wait(for: expectation2, timeout: 10_000_000)
        } catch {
            XCTFail("Timed out")
        }
        u1.cancel()
        u2.cancel()
    }

    func testVariableUnfolded() async throws {
        let expectation1 = await Expectation<Void>()
        let expectation2 = await Expectation<Void>()

        let unfolded = (0 ..< 10).asyncPublisher

        let counter1 = Counter()
        let u1 = await unfolded.sink { (result: AsyncStream<Int>.Result) in
            switch result {
                case .value:
                    counter1.increment()
                    return .more
                case let .completion(.failure(error)):
                    XCTFail("Got an error? \(error)")
                    return .done
                case .completion(.finished):
                    let count = counter1.count
                    guard count == 10 else {
                        XCTFail("Incorrect count: \(count) in subscription 1")
                        return .done
                    }
                    do { try await expectation1.complete() }
                    catch { XCTFail("Failed to complete with error: \(error)") }
                    return .done
                case .completion(.cancelled):
                    XCTFail("Should not have cancelled")
                    return .done
            }
        }

        let counter2 = Counter()
        let u2 = await unfolded.sink { (result: AsyncStream<Int>.Result) in
            switch result {
                case .value:
                    counter2.increment()
                    return .more
                case let .completion(.failure(error)):
                    XCTFail("Got an error? \(error)")
                    return .done
                case .completion(.finished):
                    let count = counter2.count
                    guard count == 10 else {
                        XCTFail("Incorrect count: \(count) in subscription 1")
                        return .done
                    }
                    do { try await expectation2.complete() }
                    catch { XCTFail("Failed to complete with error: \(error)") }
                    return .done
                case .completion(.cancelled):
                    XCTFail("Should not have cancelled")
                    return .done
            }
        }

        do {
            try await FreeCombine.wait(for: expectation1, timeout: 1_000_000)
            try await FreeCombine.wait(for: expectation2, timeout: 1_000_000)
        } catch {
            XCTFail("Timed out")
        }
        let _ = await u1.result
        let _ = await u2.result
    }
}
