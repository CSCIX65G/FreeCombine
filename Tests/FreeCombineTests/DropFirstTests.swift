//
//  DropFirstTests.swift
//  
//
//  Created by Van Simmons on 6/4/22.
//

import XCTest
@testable import FreeCombine

class DropFirstTests: XCTestCase {

    override func setUpWithError() throws { }

    override func tearDownWithError() throws { }

    func testSimpleDropFirst() async throws {
        let expectation1 = await Expectation<Void>()
        let unfolded = (0 ..< 100).asyncPublisher

        let counter1 = Counter()
        let u1 = await unfolded
            .dropFirst(27)
            .sink { (result: AsyncStream<Int>.Result) in
            switch result {
                case .value:
                    counter1.increment()
                    return .more
                case let .completion(.failure(error)):
                    XCTFail("Got an error? \(error)")
                    return .done
                case .completion(.finished):
                    let count = counter1.count
                    guard count == 73 else {
                        XCTFail("Incorrect count: \(count) in subscription 1")
                        return .done
                    }
                    do {
                        try await expectation1.complete()
                    }
                    catch { XCTFail("Failed to complete with error: \(error)") }
                    return .done
                case .completion(.cancelled):
                    XCTFail("Should not have cancelled")
                    return .done
            }
        }
        do {
            try await FreeCombine.wait(for: expectation1, timeout: 10_000_000)
        } catch {
            XCTFail("Timed out")
        }
        do {
            let finalValue = try await u1.value
            XCTAssert(finalValue == .done, "Did not complete")
        } catch {
            XCTFail("Failed to get final value")
        }
    }
}
