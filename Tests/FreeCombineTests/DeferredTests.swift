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

    func testSimpleDeferred() async throws {
        let expectation1 = await CheckedExpectation<Void>()
        let expectation2 = await CheckedExpectation<Void>()

        let count1 = Counter()
        let p =  Unfolded("abc")
        
        let d1 = Deferred { p }
        let d2 = Deferred { p }

        let c1 = await d1.sink ({ result in
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
                case .completion(.cancelled):
                    XCTFail("Should not have cancelled")
            }
            return .more
        })

        let count2 = Counter()
        let c2 = await d2.sink({ result in
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
                case .completion(.cancelled):
                    XCTFail("Should not have cancelled")
            }
            return .more
        })

        do {
            try await FreeCombine.wait(for: expectation1, timeout: 100_000_000)
            try await FreeCombine.wait(for: expectation2, timeout: 100_000_000)
        } catch {
            XCTFail("Timed out")
        }
        do {
            _ = try await c1.task.value
            _ = try await c2.task.value
        }
        catch { XCTFail("Should have completed") }
    }

    func testDeferredDefer() async throws {
        let expectation1 = await CheckedExpectation<Void>()
        let expectation2 = await CheckedExpectation<Void>()

        let count1 = Counter()
        let p = Deferred {
            Unfolded("abc")
        }
        let d1 = Deferred { p }
        let d2 = Deferred { p }

        let c1 = await d1.sink ({ result in
            switch result {
                case .value:
                    await count1.increment()
                    return .more
                case let .completion(.failure(error)):
                    XCTFail("Got an error? \(error)")
                    return .done
                case .completion(.finished):
                    let count = await count1.count
                    XCTAssert(count == 3, "wrong number of values sent: \(count)")
                    do {
                        try await expectation1.complete()
                    } catch {
                        XCTFail("Failed to complete")
                    }
                    return .done
                case .completion(.cancelled):
                    XCTFail("Should not have cancelled")
                    return .done
            }
        })

        let count2 = Counter()
        let c2 = await d2.sink({ result in
            switch result {
                case .value:
                    await count2.increment()
                    return .more
                case let .completion(.failure(error)):
                    XCTFail("Got an error? \(error)")
                    return .done
                case .completion(.finished):
                    let count = await count2.count
                    XCTAssert(count == 3, "wrong number of values sent: \(count)")
                    do {
                        try await expectation2.complete()
                    } catch {
                        XCTFail("Failed to complete")
                    }
                    return .done
                case .completion(.cancelled):
                    XCTFail("Should not have cancelled")
                    return .done
            }
        })

        do {
            try await FreeCombine.wait(for: expectation1, timeout: 100_000_000)
            try await FreeCombine.wait(for: expectation2, timeout: 100_000_000)
        } catch {
            XCTFail("Timed out")
        }
        do {
            _ = try await c1.task.value
            _ = try await c2.task.value
        }
        catch { XCTFail("Should have completed") }
    }
}
