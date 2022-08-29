//
//  MapTests.swift
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

class MapTests: XCTestCase {

    override func setUpWithError() throws { }

    override func tearDownWithError() throws { }

    func testSimpleMap() async throws {
        let expectation1 = await Expectation<Void>()

        let just = Just(7)

        let m1 = await just
            .map { $0 * 2 }
            .sink { (result: AsyncStream<Int>.Result) in
                switch result {
                    case let .value(value):
                        XCTAssert(value == 14, "wrong value sent: \(value)")
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
        
        do {
            try await FreeCombine.wait(for: expectation1, timeout: 1_000_000)
        } catch {
            XCTFail("Timed out")
        }
        _ = await m1.result
    }

    func testSimpleFutureMap() async throws {
        let expectation = await Expectation<Void>()

        let promise = try await Promise<Int>()

        let cancellation = await promise.future()
            .map { $0 * 2 }
            .sink { result in
                do { try await expectation.complete() }
                catch { XCTFail("Already used expectation") }
                
                switch result {
                    case let .success(value):
                        XCTAssert(value == 26, "wrong value sent: \(value)")
                    case let .failure(error):
                        XCTFail("Got an error? \(error)")
                }
            }

        try await promise.succeed(13)

        do {
            try await FreeCombine.wait(for: expectation, timeout: 1_000_000)
        } catch {
            XCTFail("Timed out")
        }

        _ = await cancellation.result
        promise.finish()
        _ = await promise.result
    }
}
