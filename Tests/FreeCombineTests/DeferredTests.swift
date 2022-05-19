//
//  DeferTests.swift
//
//
//  Created by Van Simmons on 2/12/22.
//

import XCTest
@testable import FreeCombine

class DeferTests: XCTestCase {

    override func setUpWithError() throws { }

    override func tearDownWithError() throws { }

    func testDeferredDefer() async throws {
        let expectation1 = await CheckedExpectation<Void>()
        let expectation2 = await CheckedExpectation<Void>()

        let count1 = Counter()
        let p = Deferred {
            Unfolded("abc")
        }
        let d1 = Deferred { p }
        let d2 = Deferred { p }

        _ = await d1.sink ({ result in
            switch result {
                case .value:
                    await count1.increment()
                case let .completion(.failure(error)):
                    XCTFail("Got an error? \(error)")
                case .completion(.finished):
                    let count = await count1.count
                    XCTAssert(count == 3, "wrong number of values sent: \(count)")
                    do {
                        try await expectation1.complete()
                    } catch {
                        XCTFail("Failed to complete")
                    }
                    return .done
            }
            return .more
        })

        let count2 = Counter()
        _ = await d2.sink({ result in
            switch result {
                case .value:
                    await count2.increment()
                case let .completion(.failure(error)):
                    XCTFail("Got an error? \(error)")
                case .completion(.finished):
                    let count = await count2.count
                    XCTAssert(count == 3, "wrong number of values sent: \(count)")
                    do {
                        try await expectation2.complete()
                    } catch {
                        XCTFail("Failed to complete")
                    }
                    return .done
            }
            return .more
        })

        await Task.yield()
        do {
            try await FreeCombine.wait(for: expectation1, timeout: 100_000_000)
            try await FreeCombine.wait(for: expectation2, timeout: 100_000_000)
        } catch {
            XCTFail("Timed out")
        }
    }
}
