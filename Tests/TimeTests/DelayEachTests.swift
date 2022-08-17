//
//  DelayEachTests.swift
//  
//
//  Created by Van Simmons on 7/4/22.
//

import XCTest
@testable import FreeCombine
@testable import Time

class DelayEachTests: XCTestCase {
    override func setUpWithError() throws {  }
    override func tearDownWithError() throws { }

    func testSimpleDelayEach() async throws {
        let expectation = await Expectation<Void>()

        let start = Date()
        let counter = Counter()
        let t = await (0 ..< 10).asyncPublisher
            .delayEach(interval: .milliseconds(100))
            .sink({ value in
                switch value {
                    case .value(_):
                        let iCount = counter.increment()
                        let count = Double(iCount)
                        let diff = start.timeIntervalSinceNow
                        XCTAssert(diff < (-0.1 * count), "Did not delay. count = \(count), interval = \(diff)")
                        XCTAssert(diff > (-0.1 * (count + 1.0)), "Delayed too much. count = \(count), interval = \(diff)")
                        return .more
                    case let .completion(.failure(error)):
                        XCTFail("Got unexpected failure: \(error)")
                        return .done
                    case .completion(.finished):
                        let count = counter.count
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

        _ = await t.result
    }
}
