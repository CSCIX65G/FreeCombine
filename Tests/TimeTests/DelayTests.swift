//
//  DelayTests.swift
//  
//
//  Created by Van Simmons on 7/4/22.
//

import XCTest
@testable import FreeCombine
@testable import Time

class DelayTests: XCTestCase {

    override func setUpWithError() throws { }

    override func tearDownWithError() throws { }

    func testSimpleDelay() async throws {
        let expectation = await Expectation<Void>()

        let start = Date()
        let counter = Counter()
        let t = await (0 ..< 100).asyncPublisher
            .delay(interval: .seconds(1))
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
            try await FreeCombine.wait(for: expectation, timeout: 2_000_000_000)
        } catch {
            t.cancel()
        }
        let count = await counter.count
        XCTAssert(count == 100, "Got wrong count = \(count)")
        let diff = start.timeIntervalSinceNow
        XCTAssert(diff < -1.0, "Did not delay.  interval = \(diff)")
        _ = await t.result
    }
}
