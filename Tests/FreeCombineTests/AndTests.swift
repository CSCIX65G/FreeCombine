//
//  AndTests.swift
//  
//
//  Created by Van Simmons on 9/2/22.
//
//  Created by Van Simmons on 6/8/22.
//
//  Copyright 2022, ComputeCycles, LLC
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//
import XCTest
@testable import FreeCombine

final class AndTests: XCTestCase {

    override func setUpWithError() throws { }

    override func tearDownWithError() throws { }

    func testSimpleAnd() async throws {
        let expectation = await Expectation<Void>()
        let promise1 = try await Promise<Int>()
        let future1 = promise1.future()
        let promise2 = try await Promise<String>()
        let future2 = promise2.future()

        let andFuture = and(future1, future2)
        let cancellation = await andFuture.sink { result in
            guard case let .success((left, right)) = result else {
                XCTFail("Failed!")
                return
            }
            XCTAssert(left == 13, "Bad left value")
            XCTAssert(right == "m", "Bad right value")
            do { try await expectation.complete() }
            catch { XCTFail("expectation failed") }
        }

        try await promise1.succeed(13)
        try await promise2.succeed("m")

        do {
            try await FreeCombine.wait(for: expectation, timeout: 1_000_000)
        } catch {
            XCTFail("Timed out")
        }

        _ = await cancellation.result
        promise1.finish()
        _ = await promise1.result
        promise2.finish()
        _ = await promise2.result
    }
}
