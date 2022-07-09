//
//  HeartbeatTests.swift
//  
//
//  Created by Van Simmons on 7/6/22.
//

import XCTest
@testable import FreeCombine
@testable import Time

class HeartbeatTests: XCTestCase {

    override func setUpWithError() throws { }

    override func tearDownWithError() throws { }

    func testSimpleHeartbeat() async throws {
        let inputCounter = Counter()
        let counter = Counter()
        var t: Cancellable<Demand>!
        t = await Heartbeat(interval: .milliseconds(500))
            .handleEvents(receiveOutput: { _ in await inputCounter.increment() })
            .sink({ value in
                switch value {
                    case .value:
                        let count = await counter.increment()
                        return count >= 10 ? .done : .more
                    case let .completion(.failure(error)):
                        XCTFail("Got unexpected failure: \(error)")
                        return .done
                    case .completion(.finished):
                        return .done
                    case .completion(.cancelled):
                        return .done
                }
            })

        let r = await t.result
        print(r)
        let count = await counter.count
        XCTAssert(count == 10, "Got wrong count = \(count)")
        let inputCount = await inputCounter.count
        XCTAssert(inputCount == 10, "Got wrong input count = \(inputCount)")
    }
}
