//
//  ThrottleDemandTests.swift
//  
//
//  Created by Van Simmons on 7/4/22.
//

import XCTest
@testable import FreeCombine
@testable import Time

class ThrottleDemandTests: XCTestCase {

    override func setUpWithError() throws { }

    override func tearDownWithError() throws { }

    func testSimpleThrottle() async throws {
        let expectation = await Expectation<Void>()

        let counter = Counter()
        let t = await (1 ... 10).asyncPublisher
            .throttleDemand(interval: .milliseconds(100))
            .sink({ value in
                switch value {
                    case .value(_):
                        await counter.increment()
                        return .more
                    case let .completion(.failure(error)):
                        XCTFail("Got unexpected failure: \(error)")
                        return .done
                    case .completion(.finished):
                        let count = await counter.count
                        do { try await expectation.complete() }
                        catch {
                            XCTFail("Failed to complete: \(error), count = \(count)")
                        }
                        return .done
                    case .completion(.cancelled):
                        XCTFail("Should not have cancelled")
                        return .done
                }
        })

        do {
            try await FreeCombine.wait(for: expectation, timeout: 1_000_000_000)
            t.cancel()
        } catch {
            let count = await counter.count
            XCTAssert(count < 12, "Got too many = \(count)")
            XCTAssert(count > 10, "Got too few = \(count)")
        }

        _ = await t.result
    }
}
