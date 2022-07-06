//
//  ThrottleTests.swift
//  
//
//  Created by Van Simmons on 7/5/22.
//

import XCTest
@testable import FreeCombine
@testable import Time

class ThrottleTests: XCTestCase {

    override func setUpWithError() throws { }

    override func tearDownWithError() throws { }

    func testSimpleThrottle() async throws {
        let expectation = await Expectation<Void>()

        let inputCounter = Counter()
        let counter = Counter()
        let t = await (1 ... 15).asyncPublisher
            .handleEvents(receiveOutput: { _ in await inputCounter.increment() })
            .throttle(interval: .milliseconds(1000), latest: false)
            .sink({ value in
                switch value {
                    case .value(_):
                        await counter.increment()
                        return .more
                    case let .completion(.failure(error)):
                        XCTFail("Got unexpected failure: \(error)")
                        return .done
                    case .completion(.finished):
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
            let inputCount = await inputCounter.count
            XCTAssert(count == 1, "Got wrong count = \(count)")
            XCTAssert(inputCount == 15, "Got wrong count = \(inputCount)")
        }

        _ = await t.result
    }
}
