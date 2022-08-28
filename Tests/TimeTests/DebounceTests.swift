//
//  DebounceTests.swift
//  
//
//  Created by Van Simmons on 7/11/22.
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

class DebounceTests: XCTestCase {
    override func setUpWithError() throws {  }
    override func tearDownWithError() throws { }

    func testSimpleDebounce() async throws {
        let values = ValueRef<[Int]>.init(value: [])
        let inputCounter = Counter()
        let counter = Counter()
        let subject = try await PassthroughSubject(Int.self)
        let t = await subject.asyncPublisher
            .handleEvents(receiveOutput: { _ in inputCounter.increment() })
            .debounce(interval: .milliseconds(100))
            .sink({ value in
                switch value {
                    case .value(let value):
                        let vals = values.value
                        values.set(value: vals + [value])
                        counter.increment()
                        return .more
                    case let .completion(.failure(error)):
                        XCTFail("Got unexpected failure: \(error)")
                        return .done
                    case .completion(.finished):
                        return .done
                    case .completion(.cancelled):
                        XCTFail("Should not have cancelled")
                        return .done
                }
            })

        for i in (0 ..< 15) {
            try await subject.blockingSend(i)
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        try await Task.sleep(nanoseconds: 100_000_000)

        try await subject.finish()
        _ = await subject.result

        let count = counter.count
        XCTAssert(count == 1, "Got wrong count = \(count)")

        let inputCount = inputCounter.count
        XCTAssert(inputCount == 15, "Got wrong count = \(inputCount)")

        let vals = values.value
        XCTAssert(vals == [14], "Incorrect values: \(vals)")

        _ = await t.result
    }

    func testMoreComplexDebounce() async throws {
        let values = ValueRef<[Int]>.init(value: [])
        let inputCounter = Counter()
        let counter = Counter()
        let subject = try await PassthroughSubject(Int.self)
        let t = await subject.asyncPublisher
            .handleEvents(receiveOutput: { _ in inputCounter.increment() })
            .debounce(interval: .milliseconds(100))
            .sink({ value in
                switch value {
                    case .value(let value):
                        let vals = values.value
                        values.set(value: vals + [value])
                        counter.increment()
                        return .more
                    case let .completion(.failure(error)):
                        XCTFail("Got unexpected failure: \(error)")
                        return .done
                    case .completion(.finished):
                        return .done
                    case .completion(.cancelled):
                        XCTFail("Should not have cancelled")
                        return .done
                }
            })

        for i in (0 ..< 15) {
            try await subject.blockingSend(i)
            try await Task.sleep(nanoseconds: i % 2 == 0 ? 50_000_000 : 110_000_000)
        }
        try await Task.sleep(nanoseconds: 100_000_000)

        try await subject.finish()
        _ = await subject.result

        let count = counter.count
        XCTAssert(count == 8, "Got wrong count = \(count)")

        let inputCount = inputCounter.count
        XCTAssert(inputCount == 15, "Got wrong count = \(inputCount)")

        let vals = values.value
        XCTAssert(vals == [1, 3, 5, 7, 9, 11, 13, 14], "Incorrect values: \(vals)")

        _ = await t.result
    }
}
