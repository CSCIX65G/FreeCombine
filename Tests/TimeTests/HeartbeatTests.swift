//
//  HeartbeatTests.swift
//  
//
//  Created by Van Simmons on 7/6/22.
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

class HeartbeatTests: XCTestCase {

    override func setUpWithError() throws { }

    override func tearDownWithError() throws { }

    func testSimpleHeartbeat() async throws {
        let inputCounter = Counter()
        let counter = Counter()
        var t: Cancellable<Demand>!
        t = await Heartbeat(interval: .milliseconds(500))
            .handleEvents(receiveOutput: { _ in inputCounter.increment() })
            .sink({ value in
                switch value {
                    case .value:
                        let count = counter.increment()
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

        _ = await t.result
        let count = counter.count
        XCTAssert(count == 10, "Got wrong count = \(count)")
        let inputCount = inputCounter.count
        XCTAssert(inputCount == 10, "Got wrong input count = \(inputCount)")
    }
}
