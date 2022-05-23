//
//  MergeTests.swift
//
//
//  Created by Van Simmons on 2/1/22.
//

import XCTest
@testable import FreeCombine

class MergeTests: XCTestCase {

    override func setUpWithError() throws { }

    override func tearDownWithError() throws { }

    func xtestSimpleMerge() async throws {
        let expectation = await CheckedExpectation<Void>()

        let publisher1 = "01234567890123".asyncPublisher
        let publisher2 = "abcdefghijklmnopqrstuvwxyz".asyncPublisher
        let publisher3 = "abcdefghijklmnopqrstuvwxyz".reversed().asyncPublisher

        let counter = Counter()
        let m1 = await merge(publishers: publisher1, publisher2, publisher3)
            .map { $0.uppercased() }
            .sink({ result in
                switch result {
                    case .value:
                        await counter.increment()
                    case let .completion(.failure(error)):
                        XCTFail("Got an error? \(error)")
                    case .completion(.finished):
                        let count = await counter.count
                        XCTAssert(count == 66, "wrong number of values sent: \(count)")
                        do { try await expectation.complete() }
                        catch { XCTFail("Failed to complete with error: \(error)") }
                        return .done
                }
                return .more
            })

        do {
            try await FreeCombine.wait(for: expectation, timeout: 100_000_000)
        } catch {
            XCTFail("Timed out")
        }
        m1.cancel()
    }
}
