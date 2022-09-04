//
//  OrTests.swift
//  
//
//  Created by Van Simmons on 9/3/22.
//

import XCTest
@testable import FreeCombine

final class OrTests: XCTestCase {
    override func setUpWithError() throws { }

    override func tearDownWithError() throws { }

    func testSimpleOr() async throws {
        let expectation = await Expectation<Void>()
        let promise1 = try await Promise<Int>()
        let future1 = promise1.future()
        let promise2 = try await Promise<Int>()
        let future2 = promise2.future()

        let orFuture = or(future1, future2)
        let cancellation = await orFuture.sink { result in
            guard case let .success(value) = result else {
                XCTFail("Failed!")
                return
            }
            XCTAssert(value == 13 || value == 14, "Bad value")
            do { try await expectation.complete() }
            catch { XCTFail("expectation failed") }
        }

        try await promise1.succeed(13)
        try await promise2.succeed(14)

        _ = await cancellation.result
    }

    func testSimpleOrFailure() async throws {
        enum Error: Swift.Error, Equatable {
            case iFailed
        }

        let expectation = await Expectation<Void>()
        let promise1 = try await Promise<Int>()
        let future1 = promise1.future()
        let promise2 = try await Promise<Int>()
        let future2 = promise2.future()

        let orFuture = or(future1, future2)
        let cancellation = await orFuture.sink { result in
            guard case let .failure = result else {
                XCTFail("Got a success when should have gotten failure!")
                return
            }
            do { try await expectation.complete() }
            catch { XCTFail("expectation failed") }
        }

        try await promise2.fail(Error.iFailed)
        try await promise1.cancel()

        _ = await cancellation.result
    }

    func testComplexOr() async throws {
        let expectation = await Expectation<Void>()
        let promise1 = try await Promise<Int>()
        let future1 = promise1.future()
        let promise2 = try await Promise<Int>()
        let future2 = promise2.future()
        let promise3 = try await Promise<Int>()
        let future3 = promise3.future()
        let promise4 = try await Promise<Int>()
        let future4 = promise4.future()
        let promise5 = try await Promise<Int>()
        let future5 = promise5.future()
        let promise6 = try await Promise<Int>()
        let future6 = promise6.future()
        let promise7 = try await Promise<Int>()
        let future7 = promise7.future()
        let promise8 = try await Promise<Int>()
        let future8 = promise8.future()

        let orFuture = or(future1, future2, future3, future4, future5, future6, future7, future8)
        let cancellation = await orFuture.sink { result in
            guard case let .success(value) = result else {
                XCTFail("Failed!")
                return
            }
            XCTAssert((13 ... 20).contains(value), "Bad value: \(value)")
            do { try await expectation.complete() }
            catch { XCTFail("expectation failed") }
        }

        try await promise1.succeed(13)
        try await promise2.succeed(14)
        try await promise3.succeed(15)
        try await promise4.succeed(16)
        try await promise5.succeed(17)
        try await promise6.succeed(18)
        try await promise7.succeed(19)
        try await promise8.succeed(20)

        _ = await cancellation.result
    }
}
