//
//  ScanTests.swift
//  
//
//  Created by Van Simmons on 5/26/22.
//
import XCTest
@testable import FreeCombine

class ScanTests: XCTestCase {

    override func setUpWithError() throws { }

    override func tearDownWithError() throws { }

    func testSimpleScan() async throws {
        let expectation = await CheckedExpectation<Void>()

        let publisher = [1, 2, 3, 1, 2, 3, 4, 1, 2, 5].asyncPublisher
        let counter = Counter()

        let c1 = await publisher
            .scan(0, max)
            .removeDuplicates()
            .sink({ result in
                switch result {
                    case let .value(value):
                        let count = await counter.count
                        XCTAssert(value == count, "Wrong value: \(value), count: \(count)")
                        await counter.increment()
                        return .more
                    case let .completion(.failure(error)):
                        XCTFail("Got an error? \(error)")
                        return .done
                    case .completion(.finished):
                        let count = await counter.count
                        XCTAssert(count == 5, "wrong number of values sent: \(count)")
                        do { try await expectation.complete() }
                        catch { XCTFail("Failed to complete: \(error)") }
                        return .done
                    case .completion(.cancelled):
                        XCTFail("Should not have cancelled")
                        return .done
                }
            })
        do { try await FreeCombine.wait(for: expectation, timeout: 1_000_000) }
        catch {
            let count = await counter.count
            XCTFail("Timed out, count = \(count)")
        }
        c1.cancel()
    }
}
