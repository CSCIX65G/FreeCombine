//
//  ScanTests.swift
//  
//
//  Created by Van Simmons on 5/26/22.
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

class ScanTests: XCTestCase {

    override func setUpWithError() throws { }

    override func tearDownWithError() throws { }

    func testSimpleScan() async throws {
        let expectation = await Expectation<Void>()

        let publisher = [1, 2, 3, 1, 2, 3, 4, 1, 2, 5].asyncPublisher
        let counter = Counter()

        let c1 = await publisher
            .scan(0, max)
            .removeDuplicates()
            .sink({ result in
                switch result {
                    case let .value(value):
                        let count = counter.count
                        XCTAssert(value == count, "Wrong value: \(value), count: \(count)")
                        counter.increment()
                        return .more
                    case let .completion(.failure(error)):
                        XCTFail("Got an error? \(error)")
                        return .done
                    case .completion(.finished):
                        let count = counter.count
                        XCTAssert(count == 5, "wrong number of values sent: \(count)")
                        do { try await expectation.complete() }
                        catch { XCTFail("Failed to complete: \(error)") }
                        return .done
                    case .completion(.cancelled):
                        XCTFail("Should not have cancelled")
                        return .done
                }
            })
        do { try await FreeCombine.wait(for: expectation, timeout: 1_000_000) }
        catch {
            let count = counter.count
            XCTFail("Timed out, count = \(count)")
        }
        let _ = await c1.result
    }
}
