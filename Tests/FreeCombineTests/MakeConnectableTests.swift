//
//  MakeConnectableTests.swift
//  
//
//  Created by Van Simmons on 6/5/22.
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

class MakeConnectableTests: XCTestCase {

    override func setUpWithError() throws { }

    override func tearDownWithError() throws { }

    func testSimpleMakeConnectable() async throws {
        let expectation1 = await Expectation<Void>()
        let expectation2 = await Expectation<Void>()

        let connectable = try await Unfolded(0 ..< 100)
            .makeConnectable()

        let p = connectable.publisher()

        let counter1 = Counter()
        let u1 = await p.sink { (result: AsyncStream<Int>.Result) in
            switch result {
                case .value:
                    counter1.increment()
                    return .more
                case let .completion(.failure(error)):
                    XCTFail("Got an error? \(error)")
                    return .done
                case .completion(.finished):
                    let count = counter1.count
                    guard count == 100 else {
                        XCTFail("Incorrect count: \(count) in subscription 1")
                        return .done
                    }
                    do { try await expectation1.complete() }
                    catch { XCTFail("Failed to complete with error: \(error)") }
                    return .done
                case .completion(.cancelled):
                    XCTFail("Should not have cancelled")
                    return .done
            }
        }

        let counter2 = Counter()
        let u2 = await p.sink { (result: AsyncStream<Int>.Result) in
            switch result {
                case .value:
                    counter2.increment()
                    return .more
                case let .completion(.failure(error)):
                    XCTFail("Got an error? \(error)")
                    return .done
                case .completion(.finished):
                    let count = counter2.count
                    guard count == 100 else {
                        XCTFail("Incorrect count: \(count) in subscription 2")
                        return .done
                    }
                    do { try await expectation2.complete() }
                    catch { XCTFail("Failed to complete with error: \(error)") }
                    return .done
                case .completion(.cancelled):
                    XCTFail("Should not have cancelled")
                    return .done
            }
        }

        do {
            try await connectable.connect()
        }
        catch {
            XCTFail("Failed to connect")
        }

        let d1 = try await u1.value
        XCTAssert(d1 == .done, "First chain has wrong value")
        let d2 = try await u2.value
        XCTAssert(d2 == .done, "Second chain has wrong value")

        let _ = await connectable.result
    }

    func testSubjectMakeConnectable() async throws {
        let subj = try await PassthroughSubject(Int.self)

        let connectable = try await subj
            .publisher()
            .map { $0 }
            .makeConnectable()

        let counter1 = Counter()
        let u1 = await connectable.publisher().sink({ result in
            switch result {
                case .value:
                    counter1.increment()
                    return .more
                case let .completion(.failure(error)):
                    XCTFail("Got an error? \(error)")
                    return .done
                case .completion(.finished):
                    let count = counter1.count
                    if count != 100 {
                        XCTFail("Incorrect count: \(count) in subscription 1")
                    }
                    return .done
                case .completion(.cancelled):
                    XCTFail("Should not have cancelled")
                    return .done
            }
        })

        let counter2 = Counter()
        let u2 = await connectable.publisher().sink { (result: AsyncStream<Int>.Result) in
            switch result {
                case .value:
                    counter2.increment()
                    return .more
                case let .completion(.failure(error)):
                    XCTFail("Got an error? \(error)")
                    return .done
                case .completion(.finished):
                    let count = counter2.count
                    if count != 100  {
                        XCTFail("Incorrect count: \(count) in subscription 2")
                    }
                    return .done
                case .completion(.cancelled):
                    XCTFail("Should not have cancelled")
                    return .done
            }
        }

        try await connectable.connect()

        for i in (0 ..< 100) {
            do { try await subj.blockingSend(i) }
            catch { XCTFail("Failed to send on \(i) with error: \(error)") }
        }

        try await subj.finish()
        _ = await subj.result
        _ = await connectable.result
        let d1 = try await u1.value
        XCTAssert(d1 == .done, "First chain has wrong value")
        let d2 = try await u2.value
        XCTAssert(d2 == .done, "Second chain has wrong value")
    }
}
