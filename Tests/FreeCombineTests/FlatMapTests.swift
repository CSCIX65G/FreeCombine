//
//  FlatMapTests.swift
//  
//
//  Created by Van Simmons on 5/19/22.
//

import XCTest
@testable import FreeCombine

class FlatMapTests: XCTestCase {

    override func setUpWithError() throws { }

    override func tearDownWithError() throws { }

    func testSimpleFlatMap() async throws {
        let expectation = await CheckedExpectation<Void>()

        let checksum = Counter()
        _ = await Unfolded(0 ... 3)
            .map { $0 * 2 }
            .flatMap { (value) -> Publisher<Int> in
                let iterator = ValueRef(value: [Int].init(repeating: value, count: value).makeIterator())
                return .init { await iterator.next() }
            }
            .sink({ result in
                switch result {
                    case let .value(value):
                        await checksum.increment(by: value)
                        return .more
                    case let .completion(.failure(error)):
                        XCTFail("Got an error? \(error)")
                        return .done
                    case .completion(.finished):
                        let value = await checksum.count
                        XCTAssert(value == 56, "Did not get all values")
                        try! await expectation.complete()
                        return .done
                }
            })

        do {
            try await FreeCombine.wait(for: expectation, timeout: 100_000_000)
        }
    }
}