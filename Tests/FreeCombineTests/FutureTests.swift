//
//  FutureTests.swift
//  
//
//  Created by Van Simmons on 8/15/22.
//

import XCTest
@testable import FreeCombine

final class FutureTests: XCTestCase {

    override func setUpWithError() throws { }

    override func tearDownWithError() throws { }

    func testSimpleFutureToPublisher() async throws {
        let expectation = await Expectation<Void>()
        let promise = try await Promise<Int>()
        let cancellation = await promise.future().publisher
            .sink ({ result in
                do { try await expectation.complete() }
                catch {
                    XCTFail("Failed completion expecation with: \(error)")
                }
                return .done
            })

        try await promise.succeed(13)

        do {
            try await FreeCombine.wait(for: expectation, timeout: 1_000_000)
        } catch {
            XCTFail("Timed out")
        }

        _ = await cancellation.result
        promise.finish()
        _ = await promise.result
    }
}
