//
//  MapTests.swift
//  
//
//  Created by Van Simmons on 3/16/22.
//

import XCTest
@testable import FreeCombine

class MapTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testSimpleMap() async throws {
        let expectation1 = await CheckedExpectation<Void>()

        let just = Just(7)

        _ = just
            .map { $0 * 2 }
            .sink(onStartup: .none) { result in
            switch result {
                case let .value(value):
                    XCTAssert(value == 14, "wrong value sent: \(value)")
                    return .more
                case let .failure(error):
                    XCTFail("Got an error? \(error)")
                    return .done
                case .terminated:
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
    }
}
