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
        _ = Empty(Int.self).sink { completion in
            guard case .finished = completion else {
                XCTFail("Should never receive value")
                return
            }
            print("Completed")
        }
    }

    func testJustPublisher() throws {
        var count = 0
        _ = Just(14).sink {
            switch $0 {
            case .value(let value):
                guard value == 14 else { XCTFail("Received incorrect value"); return }
                guard count == 0 else { XCTFail("Received more than one value"); return }
                count += 1
            default:
                print("Completed")
            }
        }
    }

    func testSequencePublisher() throws {
        var count = 0, total = 0
        _ = [1, 2, 3, 4].publisher.sink { input in
            switch input {
            case .value(let value):
                guard count < 4 else { XCTFail("Received incorrect number of calls"); return }
                guard total <= 10 else { XCTFail("Received wrong value"); return }
                count += 1
                total += value
            default:
                print("Completed")
            }
        }
    }
    
    func testSubscribing() throws {
        var count = 0, total = 0
        let subscriber = Subscriber<Int, Never>(
            .init { input in
                switch input {
                case .value(let value):
                    print(value)
                    count += 1
                    total += value
                default: ()
                }
                return .none
            }
        )
        let subscription = [1, 2, 3, 4].publisher(subscriber)
        subscription(.max(1))
        subscription(.max(1))
        subscription(.max(1))
        subscription(.max(1))
        subscription(.cancel)
        XCTAssertEqual(count, 4, "Received incorrect number of calls")
        XCTAssertEqual(total, 10, "Received wrong value")
    }
    
    func testEarlyHalt() throws {
        var count = 0
        var total = 0
        let subscriber = Subscriber<Int, Never>(
            .init { input in
                switch input {
                case .value(let value):
                    print(value)
                    count += 1
                    total += value
                default: ()
                }
                return .none
            }
        )
        let publisher = [1, 2, 3, 4].publisher
        let subscription = publisher(subscriber)
        subscription(.max(1))
        subscription(.cancel)
        subscription(.max(1))
        subscription(.max(1))
        subscription(.max(1))
        subscription(.max(1))
        XCTAssertEqual(count, 1, "Received incorrect number of calls")
        XCTAssertEqual(total, 1, "Received wrong value")
    }
}
