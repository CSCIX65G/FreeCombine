//
//  MergeTests.swift
//
//
//  Created by Van Simmons on 2/1/22.
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

class MergeTests: XCTestCase {

    override func setUpWithError() throws { }

    override func tearDownWithError() throws { }

    func testSimpleMerge() async throws {
        let expectation = await Expectation<Void>()

        let publisher1 = "01234567890123".asyncPublisher
        let publisher2 = "abcdefghijklmnopqrstuvwxyz".asyncPublisher
        let publisher3 = "abcdefghijklmnopqrstuvwxyz".reversed().asyncPublisher

        let counter = Counter()
        let m1 = await merge(publishers: publisher1, publisher2, publisher3)
            .map { $0.uppercased() }
            .sink({ result in
                switch result {
                    case .value:
                        counter.increment()
                        return .more
                    case let .completion(.failure(error)):
                        XCTFail("Got an error? \(error)")
                        return .done
                    case .completion(.finished):
                        let count = counter.count
                        XCTAssert(count == 66, "wrong number of values sent: \(count)")
                        do { try await expectation.complete() }
                        catch { XCTFail("Failed to complete with error: \(error)") }
                        return .done
                    case .completion(.cancelled):
                        XCTFail("Should not have cancelled")
                        return .done
                }
            })

        _ = await m1.result
    }

    func testInlineMerge() async throws {
        let expectation = await Expectation<Void>()

        let fseq1 = (101 ... 150).asyncPublisher
        let fseq2 = (1 ... 100).asyncPublisher

        let fm1 = Merged(fseq1, fseq2)

        let c1 = await fm1
            .sink({ value in
                switch value {
                    case .value(_):
                        return .more
                    case let .completion(.failure(error)):
                        XCTFail("Should not have received failure: \(error)")
                        return .done
                    case .completion(.finished):
                        try await expectation.complete()
                        return .done
                    case .completion(.cancelled):
                        XCTFail("Should not have cancelled")
                        return .done
                }
            })

        _ = await c1.result
    }
}
