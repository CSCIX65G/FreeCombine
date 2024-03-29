//
//  ShareTests.swift
//  
//
//  Created by Van Simmons on 6/27/22.
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

final class ShareTests: XCTestCase {

    override func setUpWithError() throws { }

    override func tearDownWithError() throws { }

    func testSimpleShare() async throws {
        /*
         p1 and p2 below are NOT guaranteed to see the same number of values bc
         the share publisher begins publishing as soon as the first subscription
         is connected.  The second subscriber will see only those published
         values that occur after it subscribes.  In some cases it will see zero
         */
        let expectation1 = await Expectation<Void>()
        let expectation2 = await Expectation<Void>()

        let n = 100
        let upstreamCounter = Counter()
        let upstreamValue = ValueRef<Int>(value: -1)
        let upstreamShared = ValueRef<Bool>(value: false)
        let shared = try await (0 ..< n)
            .asyncPublisher
            .map { $0 * 2 }
            .handleEvents(
                receiveDownstream: { _ in
                    Task<Void, Swift.Error> {
                        guard upstreamShared.value == false else {
                            XCTFail("Shared more than once")
                            return
                        }
                        upstreamShared.set(value: true)
                    }
                },
                receiveOutput: { value in
                    upstreamCounter.increment()
                    upstreamValue.set(value: value)
                },
                receiveFinished: {
                    let count = upstreamCounter.count
                    XCTAssert(count == n, "Wrong number sent, expected: \(n), got: \(count)")
                },
                receiveFailure: { error in
                    XCTFail("Inappropriately failed with: \(error)")
                },
                receiveCancel: {
                    XCTFail("Inappropriately cancelled")
                }
            )
            .share()

        let counter1 = Counter()
        let value1 = ValueRef<Int>(value: -1)
        let u1 = await shared.sink( { result in
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
        let u2 = await shared.sink( { result in
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
                    return .done
            }
        })

        do { _ = try await expectation1.value }
        catch {
            let last = value1.value
            XCTFail("u1 Timed out count = \(counter1.count), last = \(last)")
        }

        do { _ = try await expectation2.value } catch {
            let count = counter2.count
            let last = value2.value
            XCTFail("u2 Timed out count = \(count), last = \(last)")
        }

        let d1 = try await u1.value
        XCTAssert(d1 == .done, "First chain has wrong value")

        let d2 = await u2.result
        guard case .success = d2 else {
            XCTFail("Did not get successful result, got: \(d2)")
            return
        }
    }
}
