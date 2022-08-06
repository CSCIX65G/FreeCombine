//
//  PromiseTests.swift
//  
//
//  Created by Van Simmons on 8/6/22.
//
import XCTest
@testable import FreeCombine

final class PromiseTests: XCTestCase {

    override func setUpWithError() throws { }

    override func tearDownWithError() throws { }

    func testSimplePromise() async throws {
        let expectation = await Expectation<Void>()
        let promise = try await Promise<Int>()
        let cancellation = await promise.future()
            .sink ({ result in
                do { try await expectation.complete() }
                catch { XCTFail("Failed to complete with error: \(error)") }
                switch result {
                    case .success(let value):
                        XCTAssert(value == 13, "Wrong value")
                    case .failure(let error):
                        XCTFail("Failed with \(error)")
                }
            })

        try await promise.send(13)

        do {
            try await FreeCombine.wait(for: expectation, timeout: 1_000_000)
        } catch {
            XCTFail("Timed out")
        }

        _ = await cancellation.result
        _ = await promise.result
    }
}
