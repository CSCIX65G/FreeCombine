//
//  PromiseTests.swift
//  
//
//  Created by Van Simmons on 8/6/22.
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

final class PromiseTests: XCTestCase {

    override func setUpWithError() throws { }

    override func tearDownWithError() throws { }

    func testSimplePromise() async throws {
        let expectation = await Expectation<Void>()
        let promise = try await Promise<Int>()
        let cancellation = await promise.future()
            .sink ({ result in
                do { try await expectation.complete() }
                catch { XCTFail("Failed to complete with error: \(error)") }
                switch result {
                    case .success(let value):
                        XCTAssert(value == 13, "Wrong value")
                    case .failure(let error):
                        XCTFail("Failed with \(error)")
                }
            })

        try await promise.succeed(13)

        do { _ = try await expectation.value }
        catch { XCTFail("Timed out") }

        _ = await cancellation.result
    }

    func testSimpleFailedPromise() async throws {
        enum PromiseError: Error, Equatable {
            case iFailed
        }
        let expectation = await Expectation<Void>()
        let promise = try await Promise<Int>()
        let cancellation = await promise.future()
            .sink ({ result in
                do { try await expectation.complete() }
                catch { XCTFail("Failed to complete with error: \(error)") }
                switch result {
                    case .success(let value):
                        XCTFail("Got a value \(value)")
                    case .failure(let error):
                        guard let e = error as? PromiseError, e == .iFailed else {
                            XCTFail("Wrong error: \(error)")
                            return
                        }
                }
            })

        try await promise.fail(PromiseError.iFailed)

        do {  _ = try await expectation.value }
        catch { XCTFail("Timed out") }

        _ = await cancellation.result
    }

    func testMultipleSubscribers() async throws {
        let promise = try await Promise<Int>()
        let max = 1_000
        let range = 0 ..< max

        var pairs: [(Expectation<Void>, Cancellable<Void>)] = .init()
        for _ in range {
            let expectation = await Expectation<Void>()
            let cancellation = await promise.future()
                .map { $0 * 2 }
                .sink ({ result in
                    do { try await expectation.complete() }
                    catch { XCTFail("Failed to complete with error: \(error)") }
                    switch result {
                        case .success(let value): XCTAssert(value == 26, "Wrong value")
                        case .failure(let error): XCTFail("Failed with \(error)")
                    }
                })
            let pair = (expectation, cancellation)
            pairs.append(pair)
        }
        XCTAssertTrue(pairs.count == max, "Failed to create futures")
        try await promise.succeed(13)

        do {
            for pair in pairs {
                _ = try await pair.0.value
                _ = await pair.1.result
            }
        } catch {
            XCTFail("Timed out")
        }
    }

    func testMultipleSends() async throws {
        let promise = try await Promise<Int>()
        let max = 1_000
        let range = 0 ..< max

        var pairs: [(Expectation<Void>, Cancellable<Void>)] = .init()
        for _ in range {
            let expectation = await Expectation<Void>()
            let cancellation = await promise.future()
                .map { $0 * 2 }
                .sink ({ result in
                    do { try await expectation.complete() }
                    catch { XCTFail("Failed to complete with error: \(error)") }
                    switch result {
                        case .success(let value): XCTAssert(value == 26, "Wrong value")
                        case .failure(let error): XCTFail("Failed with \(error)")
                    }
                })
            let pair = (expectation, cancellation)
            pairs.append(pair)
        }
        let succeedCounter = Counter()
        let failureCounter = Counter()
        XCTAssertTrue(pairs.count == max, "Failed to create futures")
        let maxAttempts = 100
        let _: Void = try await withResumption { resumption in
            let semaphore: FreeCombine.Semaphore<Void, Void> = .init(
                resumption: resumption,
                reducer: { _, _ in return },
                initialState: (),
                count: maxAttempts
            )
            for _ in 0 ..< maxAttempts {
                Task {
                    do { try await promise.succeed(13); succeedCounter.increment(); await semaphore.decrement(with: ()) }
                    catch { failureCounter.increment(); await semaphore.decrement(with: ()) }
                }
            }
        }
        let successCount = succeedCounter.count
        XCTAssert(successCount == 1, "Too many successes")

        let failureCount = failureCounter.count
        XCTAssert(failureCount == maxAttempts - 1, "Too few failures")

        do {
            for pair in pairs {
                _ = try await pair.0.value
                _ = await pair.1.result
            }
        } catch {
            XCTFail("Timed out")
        }
    }
}
