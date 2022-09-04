//
//  JustTests.swift
//  
//
//  Created by Van Simmons on 3/16/22.
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

class JustTests: XCTestCase {

    override func setUpWithError() throws { }

    override func tearDownWithError() throws { }

    func testSimpleSynchronousJust() async throws {
        let expectation1 = await Expectation<Void>()
        let expectation2 = await Expectation<Void>()

        let just = Just(7)

        let c1 = await just.sink { (result: AsyncStream<Int>.Result) in
            switch result {
                case let .value(value):
                    XCTAssert(value == 7, "wrong value sent: \(value)")
                    return .more
                case let .completion(.failure(error)):
                    XCTFail("Got an error? \(error)")
                    return .done
                case .completion(.finished):
                    do { try await expectation1.complete() }
                    catch { XCTFail("Failed to complete with error: \(error)") }
                    return .done
                case .completion(.cancelled):
                    XCTFail("Should not have cancelled")
                    return .done
            }
        }

        let c2 = await just.sink { (result: AsyncStream<Int>.Result) in
            switch result {
                case let .value(value):
                    XCTAssert(value == 7, "wrong value sent: \(value)")
                    return .more
                case let .completion(.failure(error)):
                    XCTFail("Got an error? \(error)")
                    return .done
                case .completion(.finished):
                    do { try await expectation2.complete() }
                    catch { XCTFail("Failed to complete with error: \(error)") }
                    return .done
                case .completion(.cancelled):
                    XCTFail("Should not have cancelled")
                    return .done
            }
        }

        do {
            _ = try await expectation1.value
            _ = try await expectation2.value
        } catch {
            XCTFail("Expectations threw")
        }
        let _ = await c1.result
        let _ = await c2.result
    }

    func testSimpleSequenceJust() async throws {
        let expectation1 = await Expectation<Void>()
        let just = Just([1, 2, 3, 4])
        let c1 = await just.sink { (result: AsyncStream<[Int]>.Result) in
            switch result {
                case let .value(value):
                    XCTAssert(value == [1, 2, 3, 4], "wrong value sent: \(value)")
                    return .more
                case let .completion(.failure(error)):
                    XCTFail("Got an error? \(error)")
                    return .done
                case .completion(.finished):
                    do { try await expectation1.complete() }
                    catch {
                        XCTFail("Failed to complete with error: \(error)")
                    }
                    return .done
                case .completion(.cancelled):
                    XCTFail("Should not have cancelled")
                    return .done
            }
        }
        do {
            let finalDemand = try await c1.value
            XCTAssert(finalDemand == .done, "Incorrect return")
        } catch {
            XCTFail("Errored out")
        }
        do { _ = try await expectation1.value }
        catch { XCTFail("Timed out") }
    }

    func testSimpleAsyncJust() async throws {
        let expectation1 = await Expectation<Void>()
        let expectation2 = await Expectation<Void>()

        let just = Just(7)

        let c1 = await just.sink { (result: AsyncStream<Int>.Result) in
            switch result {
                case let .value(value):
                    XCTAssert(value == 7, "wrong value sent: \(value)")
                    return .more
                case let .completion(.failure(error)):
                    XCTFail("Got an error? \(error)")
                    return .done
                case .completion(.finished):
                    do { try await expectation1.complete() }
                    catch {
                        XCTFail("Failed to complete with error: \(error)")
                    }
                    return .done
                case .completion(.cancelled):
                    XCTFail("Should not have cancelled")
                    return .done
            }
        }

        var t: Cancellable<Demand>! = .none
        do { _ = try await withResumption { resumption in
            t = just.sink(onStartup: resumption, { result in
                switch result {
                    case let .value(value):
                        XCTAssert(value == 7, "wrong value sent: \(value)")
                        return .more
                    case let .completion(.failure(error)):
                        XCTFail("Got an error? \(error)")
                        return .done
                    case .completion(.finished):
                        do { try await expectation2.complete() }
                        catch {
                            XCTFail("Failed to complete with error: \(error)")
                        }
                        return .done
                    case .completion(.cancelled):
                        XCTFail("Should not have cancelled")
                        return .done
                }
            } )
        } } catch {
            XCTFail("Resumption failed")
        }

        do {
            let finalDemand = try await t.value
            XCTAssert(finalDemand == .done, "Incorrect return")
        } catch {
            XCTFail("Errored out")
        }
        do {
            _ = try await expectation1.value
            _ = try await expectation2.value
        } catch {
            XCTFail("Timed out")
        }

        let _ = await c1.result
    }
}
