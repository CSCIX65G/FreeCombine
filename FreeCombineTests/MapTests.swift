//
//  MapTests.swift
//  FreeCombineTests
//
//  Created by Van Simmons on 4/13/20.
//  Copyright © 2020 ComputeCycles, LLC. All rights reserved.
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

    func testMap() throws {
        var count = 0, total = 0
        _ = PublishedSequence([1, 2, 3, 4])
            .map { $0 * 2 }
            .sink(
                receiveCompletion: { completion in
                    XCTAssertEqual(count, 4,  "Completed with wrong count")
                    XCTAssertEqual(total, 20, "Completed with wrong count")
                    print("Completed")
                },
                receiveValue: { value in
                    guard count < 4 else { XCTFail("Received incorrect number of calls"); return }
                    guard total <= 20 else { XCTFail("Received wrong value"); return }
                    count += 1
                    total += value
                }
            )
    }

    func testChainedMap() throws {
        var count = 0, total = 0
        _ = PublishedSequence([1, 2, 3, 4])
            .map { $0 * 2 }
            .map { $0 / 2 }
            .sink(
                receiveCompletion: { completion in
                    XCTAssertEqual(count, 4,  "Completed with wrong count")
                    XCTAssertEqual(total, 10, "Completed with wrong count")
                    print("Completed")
                },
                receiveValue: { value in
                    guard count < 4 else { XCTFail("Received incorrect number of calls"); return }
                    guard total <= 10 else { XCTFail("Received wrong value"); return }
                    count += 1
                    total += value
                }
            )
    }
}
