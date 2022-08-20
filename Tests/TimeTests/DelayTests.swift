//
//  DelayTests.swift
//  
//
//  Created by Van Simmons on 7/4/22.
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
                        counter.increment()
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
        let count = counter.count
        XCTAssert(count == 100, "Got wrong count = \(count)")
        let diff = start.timeIntervalSinceNow
        XCTAssert(diff < -1.0, "Did not delay.  interval = \(diff)")
        _ = await t.result
    }
}
