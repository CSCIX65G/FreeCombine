//
//  FreeCombineTests.swift
//  FreeCombineTests
//
//  Created by Van Simmons on 4/6/20.
//  Copyright © 2020 ComputeCycles, LLC. All rights reserved.
//

import XCTest
@testable import FreeCombine

class FreeCombineTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testEmptyPublisher() throws {
        OriginatingPublisher<Int, Never>().sink(
            receiveCompletion: { completion in print("finished") },
            receiveValue: { _ in XCTFail("Should never receive value") }
        )
    }

    func testJustPublisher() throws {
        var count = 0
        OriginatingPublisher<Int, Never>(14).sink(
            receiveCompletion: { completion in print("finished") },
            receiveValue: { value in
                guard value == 14 else { XCTFail("Received incorrect value"); return }
                guard count == 0 else { XCTFail("Received more than one value"); return }
                count += 1
            }
        )
    }

    func testSequencePublisher() throws {
        var count = 0
        var total = 0
        OriginatingPublisher<Int, Never>([1, 2, 3, 4]).sink(
            receiveCompletion: { completion in print("finished") },
            receiveValue: { value in
                guard count < 4 else { XCTFail("Received incorrect number of calls"); return }
                guard total <= 10 else { XCTFail("Received wrong value"); return }
                count += 1
                total += value
            }
        )
    }
}
