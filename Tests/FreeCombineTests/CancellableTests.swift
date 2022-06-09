//
//  CancellableTests.swift
//  
//
//  Created by Van Simmons on 6/8/22.
//

import XCTest
@testable import FreeCombine

final class CancellableTests: XCTestCase {

    override func setUpWithError() throws { }

    override func tearDownWithError() throws { }

    func testCancellable() async throws {
        let expectation1 = await CheckedExpectation<Void>()
        let expectation2 = await CheckedExpectation<Void>()
        let expectation3 = await CheckedExpectation<Void>()

        let expectation1a = await CheckedExpectation<Bool>()
        let expectation2a = await CheckedExpectation<Bool>()
        let expectation3a = await CheckedExpectation<Bool>()

        _ = await Cancellable(task: Task<(Cancellable<Void>, Cancellable<Void>, Cancellable<Void>), Swift.Error> {
            let t1 = Cancellable(task: Task<Void, Swift.Error> {
                try await expectation1.value
                try await expectation1a.complete(Task.isCancelled)
            })
            let t2 = Cancellable(task: Task<Void, Swift.Error> {
                try await expectation2.value
                try await expectation2a.complete(Task.isCancelled)
            })
            let t3 = Cancellable(task: Task<Void, Swift.Error> {
                try await expectation3.value
                try await expectation3a.complete(Task.isCancelled)
            })
            return (t1, t2, t3)
        }).result

        try await expectation1.complete()
        try await expectation2.complete()
        try await expectation3.complete()

        let r1 = try await expectation1a.value
        let r2 = try await expectation2a.value
        let r3 = try await expectation3a.value

        XCTAssert(r1, "Inner task 1 not cancelled")
        XCTAssert(r2, "Inner task 2 not cancelled")
        XCTAssert(r3, "Inner task 3 not cancelled")
    }
}
