//
//  ShareTests.swift
//  
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

class AutoconnectTests: XCTestCase {

    override func setUpWithError() throws { }

    override func tearDownWithError() throws { }

    func testSimpleAutoconnect() async throws {
        /*
         p1 and p2 below are NOT guaranteed to see the same number of values bc
         the autoconnected publisher begins publishing as soon as the first subscription
         is connected.  The second subscriber will see only those published
         values that occur after it subscribes.  In some cases it will see zero
         */
        let expectation1 = await Expectation<Void>()
        let expectation2 = await Expectation<Void>()

        let n = 100
        let autoconnected = try await (0 ..< n)
            .asyncPublisher
            .map { $0 * 2 }
            .autoconnect(buffering: .bufferingOldest(2))

        let counter1 = Counter()
        let value1 = ValueRef<Int>(value: -1)
        let u1 = await autoconnected.sink({ result in
            switch result {
                case let .value(value):
                    counter1.increment()
                    value1.set(value: value)
                    return .more
                case let .completion(.failure(error)):
                    XCTFail("Got an error? \(error)")
                    return .done
                case .completion(.finished):
                    let count = counter1.count
                    guard count == n else {
                        XCTFail("Incorrect count: \(count) in subscription 1")
                        return .done
                    }
                    do { try await expectation1.complete() }
                    catch { XCTFail("u1 Failed to complete with error: \(error)") }
                    return .done
                case .completion(.cancelled):
                    XCTFail("u1 should not have cancelled")
                    return .done
            }
        })

        let counter2 = Counter()
        let value2 = ValueRef<Int>(value: -1)
        let u2 = await autoconnected.sink({ result in
            switch result {
                case let .value(value):
                    counter2.increment()
                    value2.set(value: value)
                    return .more
                case let .completion(.failure(error)):
                    XCTFail("u2 completed with error: \(error)")
                    do { try await expectation2.complete() }
                    catch { XCTFail("u2 Failed to complete with error: \(error)") }
                    return .done
                case .completion(.finished):
                    // NB: the number of values received here is unpredictable
                    // and may be anything 0 ... n
                    let count = counter2.count
                    XCTAssert(count <= n, "How'd we get so many?")
                    do { try await expectation2.complete() }
                    catch { XCTFail("u2 Failed to complete with error: \(error)") }
                    return .done
                case .completion(.cancelled):
                    let count = counter2.count
                    let last = value2.value
                    XCTFail("u2 should not have cancelled, count = \(count), last = \(last)")
                    return .done
            }
        })

        let d1 = try await u1.value
        XCTAssert(d1 == .done, "First chain has wrong value")

        let d2 = await u2.cancelAndAwaitResult()
        guard case .success = d2 else {
            XCTFail("Did not get successful result, got: \(d2)")
            return
        }
    }

    func testSimpleShortAutoconnect() async throws {
        /*
         p1 and p2 below are NOT guaranteed to see the same number of values bc
         the autoconnectd publisher begins publishing as soon as the first subscription
         is connected.  The second subscriber will see only those published
         values that occur after it subscribes.  In some cases it will see zero
         */
        let expectation1 = await Expectation<Void>()
        let expectation2 = await Expectation<Void>()

        let n = 1
        let autoconnected = try await (0 ..< n)
            .asyncPublisher
            .map { $0 * 2 }
            .autoconnect(buffering: .bufferingOldest(2))

        let counter1 = Counter()
        let value1 = ValueRef<Int>(value: -1)
        let u1 = await autoconnected.sink({ result in
            switch result {
                case let .value(value):
                    counter1.increment()
                    value1.set(value: value)
                    return .more
                case let .completion(.failure(error)):
                    XCTFail("Got an error? \(error)")
                    return .done
                case .completion(.finished):
                    let count = counter1.count
                    guard count == n else {
                        XCTFail("Incorrect count: \(count) in subscription 1")
                        return .done
                    }
                    do { try await expectation1.complete() }
                    catch { XCTFail("u1 Failed to complete with error: \(error)") }
                    return .done
                case .completion(.cancelled):
                    XCTFail("u1 should not have cancelled")
                    return .done
            }
        })

        let counter2 = Counter()
        let value2 = ValueRef<Int>(value: -1)
        let u2 = await autoconnected.sink({ result in
            switch result {
                case let .value(value):
                    counter2.increment()
                    value2.set(value: value)
                    return .more
                case let .completion(.failure(error)):
                    XCTFail("u2 completed with error: \(error)")
                    do { try await expectation2.complete() }
                    catch { XCTFail("u2 Failed to complete with error: \(error)") }
                    return .done
                case .completion(.finished):
                    // NB: the number of values received here is unpredictable
                    do { try await expectation2.complete() }
                    catch { XCTFail("u2 Failed to complete with error: \(error)") }
                    return .done
                case .completion(.cancelled):
                    let count = counter2.count
                    let last = value2.value
                    XCTFail("u2 should not have cancelled, count = \(count), last = \(last)")
                    return .done
            }
        })

        let d1 = try await u1.value
        XCTAssert(d1 == .done, "First chain has wrong value")

        _ = await u2.result
    }

    func testSimpleEmptyAutoconnect() async throws {
        /*
         p1 and p2 below are NOT guaranteed to see the same number of values bc
         the autoconnectd publisher begins publishing as soon as the first subscription
         is connected.  The second subscriber will see only those published
         values that occur after it subscribes.  In some cases it will see zero
         */
        let expectation1 = await Expectation<Void>()
        let expectation2 = await Expectation<Void>()

        let n = 0
        let autoconnected = try await (0 ..< n)
            .asyncPublisher
            .map { $0 * 2 }
            .autoconnect()

        let counter1 = Counter()
        let value1 = ValueRef<Int>(value: -1)
        let u1 = await autoconnected.sink({ result in
            switch result {
                case let .value(value):
                    counter1.increment()
                    value1.set(value: value)
                    return .more
                case let .completion(.failure(error)):
                    XCTFail("Got an error? \(error)")
                    return .done
                case .completion(.finished):
                    let count = counter1.count
                    guard count == n else {
                        XCTFail("Incorrect count: \(count) in subscription 1")
                        return .done
                    }
                    do { try await expectation1.complete() }
                    catch { XCTFail("u1 Failed to complete with error: \(error)") }
                    return .done
                case .completion(.cancelled):
                    XCTFail("u1 should not have cancelled")
                    return .done
            }
        })

        let counter2 = Counter()
        let value2 = ValueRef<Int>(value: -1)
        let u2 = await autoconnected.sink({ result in
            switch result {
                case let .value(value):
                    counter2.increment()
                    value2.set(value: value)
                    return .more
                case let .completion(.failure(error)):
                    XCTFail("u2 completed with error: \(error)")
                    do { try await expectation2.complete() }
                    catch { XCTFail("u2 Failed to complete with error: \(error)") }
                    return .done
                case .completion(.finished):
                    // NB: the number of values received here is unpredictable
                    do { try await expectation2.complete() }
                    catch { XCTFail("u2 Failed to complete with error: \(error)") }
                    return .done
                case .completion(.cancelled):
                    let count = counter2.count
                    let last = value2.value
                    XCTFail("u2 should not have cancelled, count = \(count), last = \(last)")
                    return .done
            }
        })

        let d1 = try await u1.value
        XCTAssert(d1 == .done, "First chain has wrong value")

        _ = await u2.result
    }
    func testSubjectAutoconnect() async throws {
        /*
         p1 and p2 below should see the same number of values bc
         we set them up before we send to the subject
         */
        let subject = try await PassthroughSubject(Int.self)

        /*
         Note that we don't need the `.bufferingOldest(2)` here.  Bc
         we are not trying to simultaneously subscribe and send.
         */
        let publisher = try await subject.asyncPublisher
            .map { $0 % 47 }
            .autoconnect()

        let counter1 = Counter()
        let p1 = await publisher.sink( { result in
            switch result {
                case .value:
                    counter1.increment()
                    return .more
                case let .completion(.failure(error)):
                    XCTFail("Got an error? \(error)")
                    return .done
                case .completion(.finished):
                    let count = counter1.count
                    XCTAssert(count == 100, "Incorrect count: \(count) in subscription 1")
                    return .done
                case .completion(.cancelled):
                    XCTFail("Should not have cancelled")
                    return .done
            }
        })

        let counter2 = Counter()
        let p2 = await publisher.sink { (result: AsyncStream<Int>.Result) in
            switch result {
                case .value:
                    counter2.increment()
                    return .more
                case let .completion(.failure(error)):
                    XCTFail("Got an error? \(error)")
                    return .done
                case .completion(.finished):
                    let count = counter2.count
                    XCTAssert(count == 100, "Incorrect count: \(count) in subscription 2")
                    return .done
                case .completion(.cancelled):
                    XCTFail("Should not have cancelled")
                    return .done
            }
        }

        for i in (0 ..< 100) {
            do { try await subject.blockingSend(i) }
            catch { XCTFail("Failed to send on \(i)") }
        }

        try await subject.finish()
        let d1 = try await p1.value
        XCTAssert(d1 == .done, "First chain has wrong value")
        let d2 = try await p2.value
        XCTAssert(d2 == .done, "Second chain has wrong value")
        _ = await subject.result
    }
}
