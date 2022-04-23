//
//  ZipTests.swift
//  
//
//  Created by Van Simmons on 3/21/22.
//

import XCTest
@testable import FreeCombine

class ZipTests: XCTestCase {

    override func setUpWithError() throws { }

    override func tearDownWithError() throws { }

    func testSimpleZip() async throws {
        let expectation = await CheckedExpectation<Void>()

        let publisher1 = Just(100)
        let publisher2 = Just("abcdefghijklmnopqrstuvwxyz")

        let counter = Counter()

        _ = await zip(publisher1, publisher2)
            .sink { (result: AsyncStream<(Int, String)>.Result) in
                let count = await counter.count
                switch result {
                    case let .value(value):
                        _ = await counter.increment()
                        XCTAssertTrue(value.0 == 100, "Incorrect Int value")
                        XCTAssertTrue(value.1 == "abcdefghijklmnopqrstuvwxyz", "Incorrect String value")
                    case let .failure(error):
                        XCTFail("Got an error? \(error)")
                    case .terminated:
                        XCTAssert(count == 1, "wrong number of values sent: \(count)")
                        do {  try await expectation.complete() }
                        catch { XCTFail("Failed to complete: \(error)") }
                        return .done
                }
                return .more
            }
        await Task.yield()

        do { try await FreeCombine.wait(for: expectation, timeout: 100_000_000) }
        catch {
            let count = await counter.count
            XCTFail("Timed out, count = \(count)")
        }
    }

    func testEmptyZip() async throws {
        let expectation = await CheckedExpectation<Void>()

        let publisher1 = Just(100)
        let publisher2 = Empty(String.self)

        let counter = Counter()

        _ = await zip(publisher1, publisher2)
            .sink { (result: AsyncStream<(Int, String)>.Result) in
                let count = await counter.count
                switch result {
                    case let .value(value):
                        _ = await counter.increment()
                        XCTFail("Should not have received a value: \(value)")
                    case let .failure(error):
                        XCTFail("Got an error? \(error)")
                    case .terminated:
                        XCTAssert(count == 0, "wrong number of values sent: \(count)")
                        do {  try await expectation.complete() }
                        catch { XCTFail("Failed to complete: \(error)") }
                        return .done
                }
                return .more
            }
        await Task.yield()

        do { try await FreeCombine.wait(for: expectation, timeout: 100_000_000) }
        catch {
            let count = await counter.count
            XCTFail("Timed out, count = \(count)")
        }
    }
}
