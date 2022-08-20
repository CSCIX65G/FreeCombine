//
//  ZipTests.swift
//  
//
//  Created by Van Simmons on 3/21/22.
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

class ZipTests: XCTestCase {

    override func setUpWithError() throws { }

    override func tearDownWithError() throws { }

    func testSimpleJustZip() async throws {
        let expectation = await Expectation<Void>()

        let publisher1 = Just(100)
        let publisher2 = Just("abcdefghijklmnopqrstuvwxyz")

        let counter = Counter()

        let c1 = await zip(publisher1, publisher2)
            .sink { (result: AsyncStream<(Int, String)>.Result) in
                let count = counter.count
                switch result {
                    case let .value(value):
                        _ = counter.increment()
                        XCTAssertTrue(value.0 == 100, "Incorrect Int value")
                        XCTAssertTrue(value.1 == "abcdefghijklmnopqrstuvwxyz", "Incorrect String value")
                    case let .completion(.failure(error)):
                        XCTFail("Got an error? \(error)")
                    case .completion(.finished):
                        XCTAssert(count == 1, "wrong number of values sent: \(count)")
                        do {  try await expectation.complete() }
                        catch { XCTFail("Failed to complete: \(error)") }
                        return .done
                    case .completion(.cancelled):
                        XCTFail("Should not have cancelled")
                        return .done
                }
                return .more
            }

        do { try await FreeCombine.wait(for: expectation, timeout: 10_000_000) }
        catch {
            XCTFail("Timed out, count = \(counter.count)")
        }
        _ = await c1.result
    }

    func testEmptyZip() async throws {
        let expectation = await Expectation<Void>()

        let publisher1 = Just(100)
        let publisher2 = Empty(String.self)

        let counter = Counter()

        let z1 = await zip(publisher1, publisher2)
            .sink { (result: AsyncStream<(Int, String)>.Result) in
                let count = counter.count
                switch result {
                    case let .value(value):
                        _ = counter.increment()
                        XCTFail("Should not have received a value: \(value)")
                    case let .completion(.failure(error)):
                        XCTFail("Got an error? \(error)")
                    case .completion(.finished):
                        XCTAssert(count == 0, "wrong number of values sent: \(count)")
                        do {  try await expectation.complete() }
                        catch { XCTFail("Failed to complete: \(error)") }
                        return .done
                    case .completion(.cancelled):
                        XCTFail("Should not have cancelled")
                        return .done
                }
                return .more
            }

        do { try await FreeCombine.wait(for: expectation, timeout: 10_000_000) }
        catch {
            let count = counter.count
            XCTFail("Timed out, count = \(count)")
        }
        _ = await z1.result
    }

    func testSimpleSequenceZip() async throws {
        let expectation = await Expectation<Void>()

        let publisher1 = (0 ... 100).asyncPublisher
        let publisher2 = "abcdefghijklmnopqrstuvwxyz".asyncPublisher

        let counter = Counter()
        let z1 = await zip(publisher1, publisher2)
            .sink { (result: AsyncStream<(Int, Character)>.Result) in
                let count = counter.count
                switch result {
                    case .value:
                        _ = counter.increment()
                        return .more
                    case let .completion(.failure(error)):
                        XCTFail("Got an error? \(error)")
                        return .done
                    case .completion(.finished):
                        XCTAssert(count == 26, "wrong number of values sent: \(count)")
                        do {  try await expectation.complete() }
                        catch { XCTFail("Failed to complete: \(error)") }
                        return .done
                    case .completion(.cancelled):
                        XCTFail("Should not have cancelled")
                        return .done
                }
            }

        do { try await FreeCombine.wait(for: expectation, timeout: 10_000_000) }
        catch { XCTFail("Timed out, count = \(counter.count)") }
        _ = await z1.result
    }

    func testSimpleZip() async throws {
        let expectation = await Expectation<Void>()

        let publisher1 = (0 ... 100).asyncPublisher
        let publisher2 = Unfolded("abcdefghijklmnopqrstuvwxyz")

        let counter = Counter()

        let z1 = await zip(publisher1, publisher2)
            .map {value in (value.0 + 100, value.1.uppercased()) }
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
                        XCTAssert(count == 26, "wrong number of values sent: \(count)")
                        do { try await expectation.complete() }
                        catch { XCTFail("Failed to complete: \(error)") }
                        return .done
                    case .completion(.cancelled):
                        XCTFail("Should not have cancelled")
                        return .done
                }
            })

        do { try await FreeCombine.wait(for: expectation, timeout: 10_000_000) }
        catch { XCTFail("Timed out, count = \(counter.count)") }
        z1.cancel()
    }

    func testComplexZip() async throws {
        let expectation = await Expectation<Void>()

        let p1 = Unfolded(0 ... 100)
        let p2 = Unfolded("abcdefghijklmnopqrstuvwxyz")
        let p3 = Unfolded(0 ... 100)
        let p4 = Unfolded("abcdefghijklmnopqrstuvwxyz")
        let p5 = Unfolded(0 ... 100)
        let p6 = Unfolded("abcdefghijklmnopqrstuvwxyz")
        let p7 = Unfolded(0 ... 100)
        let p8 = Unfolded("abcdefghijklmnopqrstuvwxyz")

        let counter = Counter()
        let z1 = await zip(p1, p2, p3, p4, p5, p6, p7, p8)
            .map { v in
                (v.0 + 100, v.1.uppercased(), v.2 + 110, v.3, v.4 + 120, v.5.uppercased(), v.6 + 130, v.7 )
            }
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
                        XCTAssert(count == 26, "wrong number of values sent: \(count)")
                        do { try await expectation.complete() }
                        catch { XCTFail("Multiple finishes sent: \(error)") }
                        return .done
                    case .completion(.cancelled):
                        XCTFail("Should not have cancelled")
                        return .done
                }
            })

        do { try await FreeCombine.wait(for: expectation, timeout: 10_000_000) }
        catch { XCTFail("Timed out, count = \(counter.count)") }
        let _ = await z1.result
    }

    func testMultiComplexZip() async throws {
        let expectation1 = await Expectation<Void>()
        let expectation2 = await Expectation<Void>()

        let p1 = Unfolded(0 ... 100)
        let p2 = Unfolded("abcdefghijklmnopqrstuvwxyz")
        let p3 = Unfolded(0 ... 100)
        let p4 = Unfolded("abcdefghijklmnopqrstuvwxyz")
        let p5 = Unfolded(0 ... 100)
        let p6 = Unfolded("abcdefghijklmnopqrstuvwxyz")
        let p7 = Unfolded(0 ... 100)
        let p8 = Unfolded("abcdefghijklmnopqrstuvwxyz")

        let zipped = zip(p1, p2, p3, p4, p5, p6, p7, p8)

        let count1 = Counter()
        let z1 = await zipped
            .map { v in
                (v.0 + 100, v.1.uppercased(), v.2 + 110, v.3, v.4 + 120, v.5.uppercased(), v.6 + 130, v.7 )
            }
            .sink({ result in
                switch result {
                    case .value:
                        count1.increment()
                        return .more
                    case let .completion(.failure(error)):
                        XCTFail("Got an error? \(error)")
                        return .done
                    case .completion(.finished):
                        let count = count1.count
                        XCTAssert(count == 26, "wrong number of values sent: \(count1)")
                        try await expectation1.complete()
                        return .done
                    case .completion(.cancelled):
                        XCTFail("Should not have cancelled")
                        return .done
                }
            })

        let count2 = Counter()
        let z2 = await zipped
            .map { v in
                (v.0 + 100, v.1.uppercased(), v.2 + 110, v.3, v.4 + 120, v.5.uppercased(), v.6 + 130, v.7 )
            }
            .sink({ result in
                switch result {
                    case .value:
                        count2.increment()
                        return .more
                    case let .completion(.failure(error)):
                        XCTFail("Got an error? \(error)")
                        return .more
                    case .completion(.finished):
                        let count = count2.count
                        XCTAssert(count == 26, "wrong number of values sent: \(count)")
                        try await expectation2.complete()
                        return .done
                    case .completion(.cancelled):
                        XCTFail("Should not have cancelled")
                        return .done
                }
            })

        do {
            try await FreeCombine.wait(for: expectation1, timeout: 10_000_000)
            try await FreeCombine.wait(for: expectation2, timeout: 10_000_000)
        } catch {
            XCTFail("Timed out")
        }
        _ = await z1.result
        _ = await z2.result
    }
}
