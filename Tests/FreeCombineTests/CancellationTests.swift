//
//  CancellationTests.swift
//  
//
//  Created by Van Simmons on 5/15/22.
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

class CancellationTests: XCTestCase {

    override func setUpWithError() throws { }

    override func tearDownWithError() throws { }

    func testSimpleZipCancellation() async throws {
        let expectation = await Expectation<Void>()
        let waiter = await Expectation<Void>()
        let startup = await Expectation<Void>()

        let publisher1 = (0 ... 100).asyncPublisher
        let publisher2 = "abcdefghijklmnopqrstuvwxyz".asyncPublisher

        let counter = Counter()
        let z1 = await zip(publisher1, publisher2)
            .map { ($0.0 + 100, $0.1.uppercased()) }
            .sink { (result: AsyncStream<(Int, String)>.Result) in
                switch result {
                    case .value:
                        let count = counter.increment()
                        if count > 9 {
                            try await startup.complete()
                            try await waiter.value
                            return .more
                        }
                        if Task.isCancelled {
                            XCTFail("Got values after cancellation")
                            do { try await expectation.complete() }
                            catch { XCTFail("Failed to complete: \(error)") }
                            return .done
                        }
                    case let .completion(.failure(error)):
                        XCTFail("Got an error? \(error)")
                    case .completion(.finished):
                        XCTFail("Got to end of task that should have been cancelled")
                        do { try await expectation.complete() }
                        catch { XCTFail("Failed to complete: \(error)") }
                        return .done
                    case .completion(.cancelled):
                        try await expectation.complete()
                        return .done
                }
                return .more
            }

        try await startup.value
        z1.cancel()
        try await waiter.complete()

        _ = await z1.result
    }

    func testMultiZipCancellation() async throws {
        let expectation = await Expectation<Void>()
        let expectation2 = await Expectation<Void>()
        let waiter = await Expectation<Void>()
        let startup1 = await Expectation<Void>()
        let startup2 = await Expectation<Void>()

        let publisher1 = Unfolded(0 ... 100)
        let publisher2 = Unfolded("abcdefghijklmnopqrstuvwxyz")

        let counter1 = Counter()
        let counter2 = Counter()
        let zipped = zip(publisher1, publisher2)
            .map { ($0.0 + 100, $0.1.uppercased()) }

        let z1 = await zipped.sink({ result in
            switch result {
                case .value:
                    let count2 = counter2.increment()
                    if (count2 == 1) {
                        try await startup1.complete()
                    }
                    return .more
                case let .completion(.failure(error)):
                    XCTFail("Got an error? \(error)")
                    return .done
                case .completion(.finished):
                    let count2 = counter2.count
                    XCTAssertTrue(count2 == 26, "Incorrect count: \(count2)")
                    do { try await expectation2.complete() }
                    catch { XCTFail("Multiple finishes sent: \(error)") }
                    return .done
                case .completion(.cancelled):
                    XCTFail("Should not have cancelled")
                    try await expectation2.complete()
                    return .done
            }
        })

        let z2 = await zipped
            .sink({ result in
                switch result {
                    case .value:
                        let count1 = counter1.increment()
                        if count1 == 10 {
                            try await startup2.complete()
                            try await waiter.value
                            return .more
                        }
                        if count1 > 10 {
                            XCTFail("Received values after cancellation")
                        }
                        return .more
                    case let .completion(.failure(error)):
                        XCTFail("Got an error? \(error)")
                        return .done
                    case .completion(.finished):
                        XCTFail("Got to end of task that should have been cancelled")
                        do { try await expectation.complete() }
                        catch { XCTFail("Multiple finishes sent: \(error)") }
                        return .done
                    case .completion(.cancelled):
                        try await expectation.complete()
                        return .done
                }
            })

        try await startup1.value
        try await startup2.value
        z2.cancel()
        try await waiter.complete()

        _ = await z1.result
        _ = await z2.result
    }

    func testSimpleMergeCancellation() async throws {
        let expectation = await Expectation<Void>()
        let waiter = await Expectation<Void>()
        let startup = await Expectation<Void>()

        let publisher1 = "zyxwvutsrqponmlkjihgfedcba".asyncPublisher
        let publisher2 = "abcdefghijklmnopqrstuvwxyz".asyncPublisher

        let counter = Counter()
        let z1 = await merge(publishers: publisher1, publisher2)
            .map { $0.uppercased() }
            .sink({ result in
                switch result {
                    case .value:
                        let count = counter.increment()
                        if count > 9 {
                            try await startup.complete()
                            try await waiter.value
                        }
                        if count > 10 && Task.isCancelled {
                            XCTFail("Got values after cancellation")
                        }
                        return .more
                    case let .completion(.failure(error)):
                        XCTFail("Got an error? \(error)")
                        return .done
                    case .completion(.finished):
                        XCTFail("Got to end of task that should have been cancelled")
                        do {
                            try await expectation.complete()
                        }
                        catch { XCTFail("Failed to complete: \(error)") }
                        return .done
                    case .completion(.cancelled):
                        let count = counter.count
                        XCTAssert(count == 10, "Incorrect count")
                        try await expectation.complete()
                        return .done
                }
            })

        try await startup.value
        z1.cancel()
        try await waiter.complete()
        _ = await z1.result
    }
}
