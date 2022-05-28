//
//  MapTests.swift
//  
//
//  Created by Van Simmons on 3/16/22.
//

import XCTest
@testable import FreeCombine

class MapTests: XCTestCase {

    override func setUpWithError() throws { }

    override func tearDownWithError() throws { }

    func testSimpleMap() async throws {
        let expectation1 = await CheckedExpectation<Void>()

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
                }
            }
        
        do {
            try await FreeCombine.wait(for: expectation1, timeout: 1_000_000)
        } catch {
            XCTFail("Timed out")
        }
        m1.cancel()
    }
}
