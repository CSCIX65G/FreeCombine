//
//  ConcatTests.swift
//
//
//  Created by Van Simmons on 2/4/22.
//

import XCTest
@testable import FreeCombine

class ConcatTests: XCTestCase {

    override func setUpWithError() throws { }

    override func tearDownWithError() throws { }

    func testSimpleConcat() async throws {
        let expectation = await CheckedExpectation<Void>()

        let publisher1 = "0123456789".asyncPublisher
        let publisher2 = "abcdefghijklmnopqrstuvwxyz".asyncPublisher
        let publisher3 = "ZYXWVU".asyncPublisher

        let count = Counter()
        let c1 = await Concat(publisher1, publisher2, publisher3)
            .sink({ result in
                switch result {
                    case .value:
                        await count.increment()
                    case let .completion(.failure(error)):
                        XCTFail("Got an error? \(error)")
                    case .completion(.finished):
                        let n = await count.count
                        XCTAssert(n == 42, "wrong number of values sent: \(n)")
                        do {
                            try await expectation.complete()
                        } catch {
                            XCTFail("Could not complete: \(error)")
                        }
                        return .done
                }
                return .more
            })

        do {
            try await FreeCombine.wait(for: expectation, timeout: 100_000_000)
        } catch {
            XCTFail("Timed out")
        }
        c1.cancel()
    }

    func testMultiConcat() async throws {
        let expectation1 = await CheckedExpectation<Void>()
        let expectation2 = await CheckedExpectation<Void>()

        let publisher1 = "0123456789".asyncPublisher
        let publisher2 = "abcdefghijklmnopqrstuvwxyz".asyncPublisher
        let publisher3 = "ZYXWVU".asyncPublisher

        let publisher = Concat(publisher1, publisher2, publisher3)

        let count1 = Counter()
        let c1 = await publisher
            .sink({ result in
                switch result {
                    case .value:
                        await count1.increment()
                    case let .completion(.failure(error)):
                        XCTFail("Got an error? \(error)")
                    case .completion(.finished):
                        let count = await count1.count
                        XCTAssert(count == 42, "wrong number of values sent: \(count)")
                        do {
                            try await expectation1.complete()
                        } catch {
                            XCTFail("Failed to complete branch 1: \(error)")
                        }
                        return .done
                }
                return .more
            })

        let count2 = Counter()
        let c2 = await publisher
            .sink({ result in
                switch result {
                    case .value:
                        await count2.increment()
                    case let .completion(.failure(error)):
                        XCTFail("Got an error? \(error)")
                    case .completion(.finished):
                        let count = await count2.count
                        XCTAssert(count == 42, "wrong number of values sent: \(count)")
                        do {
                            try await expectation2.complete()
                        } catch {
                            XCTFail("Failed to complete branch 2: \(error)")
                        }
                        return .done
                }
                return .more
            })

        do {
            try await FreeCombine.wait(for: expectation1, timeout: 100_000_000)
            try await FreeCombine.wait(for: expectation2, timeout: 100_000_000)
        } catch {
            XCTFail("Timed out")
        }
        c1.cancel()
        c2.cancel()
    }
}
