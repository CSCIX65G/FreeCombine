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

    func testSimpleFailedPromise() async throws {
        enum PromiseError: Error, Equatable {
            case iFailed
        }
        let expectation = await Expectation<Void>()
        let promise = try await Promise<Int>()
        let cancellation = await promise.future()
            .sink ({ result in
                do { try await expectation.complete() }
                catch { XCTFail("Failed to complete with error: \(error)") }
                switch result {
                    case .success(let value):
                        XCTFail("Got a value \(value)")
                    case .failure(let error):
                        guard let e = error as? PromiseError, e == .iFailed else {
                            XCTFail("Wrong error: \(error)")
                            return
                        }
                }
            })

        try await promise.fail(PromiseError.iFailed)

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
