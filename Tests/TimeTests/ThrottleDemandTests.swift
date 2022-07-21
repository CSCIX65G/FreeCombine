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
        let t = await (0 ... 15).asyncPublisher
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
                        XCTFail("Should not reach this")
                        return .done
                    case .completion(.cancelled):
                        return .done
                }
        })

        do {
            try await FreeCombine.wait(for: expectation, timeout: 1_000_000_000)
        } catch {
            t.cancel()
            let count = await counter.count
            XCTAssert(count == 10, "Got wrong count = \(count)")
        }

        _ = await t.result
    }
}
