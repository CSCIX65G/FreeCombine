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
        let expectation = await Expectation<Void>()

        let checksum = Counter()
        let c1 = await Unfolded(0 ... 3)
            .map { $0 * 2 }
            .flatMap { (value) -> Publisher<Int> in
                [Int].init(repeating: value, count: value).asyncPublisher
            }
            .sink({ result in
                switch result {
                    case let .value(value):
                        checksum.increment(by: value)
                        return .more
                    case let .completion(.failure(error)):
                        XCTFail("Got an error? \(error)")
                        return .done
                    case .completion(.finished):
                        let value = checksum.count
                        XCTAssert(value == 56, "Did not get all values")
                        try! await expectation.complete()
                        return .done
                    case .completion(.cancelled):
                        XCTFail("Should not have cancelled")
                        return .done
                }
            })

        do {
            try await FreeCombine.wait(for: expectation, timeout: 10_000_000)
        }
        let _ = await c1.result
    }
}
