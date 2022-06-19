//
//  JustTests.swift
//  
//
//  Created by Van Simmons on 3/16/22.
//

import XCTest
@testable import FreeCombine

class JustTests: XCTestCase {

    override func setUpWithError() throws { }

    override func tearDownWithError() throws { }

    func testSimpleSynchronousJust() async throws {
        let expectation1 = await Expectation<Void>()
        let expectation2 = await Expectation<Void>()

        let just = Just(7)

        let c1 = await just.sink { (result: AsyncStream<Int>.Result) in
            switch result {
                case let .value(value):
                    XCTAssert(value == 7, "wrong value sent: \(value)")
                    return .more
                case let .completion(.failure(error)):
                    XCTFail("Got an error? \(error)")
                    return .done
                case .completion(.finished):
                    do { try await expectation1.complete() }
                    catch { XCTFail("Failed to complete with error: \(error)") }
                    return .done
                case .completion(.cancelled):
                    XCTFail("Should not have cancelled")
                    return .done
            }
        }

        let c2 = await just.sink { (result: AsyncStream<Int>.Result) in
            switch result {
                case let .value(value):
                    XCTAssert(value == 7, "wrong value sent: \(value)")
                    return .more
                case let .completion(.failure(error)):
                    XCTFail("Got an error? \(error)")
                    return .done
                case .completion(.finished):
                    do { try await expectation2.complete() }
                    catch { XCTFail("Failed to complete with error: \(error)") }
                    return .done
                case .completion(.cancelled):
                    XCTFail("Should not have cancelled")
                    return .done
            }
        }

        do {
            try await FreeCombine.wait(for: expectation1, timeout: 1_000_000)
            try await FreeCombine.wait(for: expectation2, timeout: 1_000_000)
        } catch {
            XCTFail("Timed out")
        }
        let _ = await c1.result
        let _ = await c2.result
    }

    func testSimpleSequenceJust() async throws {
        let expectation1 = await Expectation<Void>()
        let just = Just([1, 2, 3, 4])
        let c1 = await just.sink { (result: AsyncStream<[Int]>.Result) in
            switch result {
                case let .value(value):
                    XCTAssert(value == [1, 2, 3, 4], "wrong value sent: \(value)")
                    return .more
                case let .completion(.failure(error)):
                    XCTFail("Got an error? \(error)")
                    return .done
                case .completion(.finished):
                    do { try await expectation1.complete() }
                    catch {
                        XCTFail("Failed to complete with error: \(error)")
                    }
                    return .done
                case .completion(.cancelled):
                    XCTFail("Should not have cancelled")
                    return .done
            }
        }
        do {
            let finalDemand = try await c1.value
            XCTAssert(finalDemand == .done, "Incorrect return")
        } catch {
            XCTFail("Errored out")
        }
        do {
            try await FreeCombine.wait(for: expectation1, timeout: 10_000_000)
        } catch {
            XCTFail("Timed out")
        }
    }

    func testSimpleAsyncJust() async throws {
        let expectation1 = await Expectation<Void>()
        let expectation2 = await Expectation<Void>()

        let just = Just(7)

        let c1 = await just.sink { (result: AsyncStream<Int>.Result) in
            switch result {
                case let .value(value):
                    XCTAssert(value == 7, "wrong value sent: \(value)")
                    return .more
                case let .completion(.failure(error)):
                    XCTFail("Got an error? \(error)")
                    return .done
                case .completion(.finished):
                    do { try await expectation1.complete() }
                    catch {
                        XCTFail("Failed to complete with error: \(error)")
                    }
                    return .done
                case .completion(.cancelled):
                    XCTFail("Should not have cancelled")
                    return .done
            }
        }

        var t: Cancellable<Demand>! = .none
        _ = await withUnsafeContinuation { continuation in
            t = just.sink(onStartup: continuation, { result in
                switch result {
                    case let .value(value):
                        XCTAssert(value == 7, "wrong value sent: \(value)")
                        return .more
                    case let .completion(.failure(error)):
                        XCTFail("Got an error? \(error)")
                        return .done
                    case .completion(.finished):
                        do { try await expectation2.complete() }
                        catch {
                            XCTFail("Failed to complete with error: \(error)")
                        }
                        return .done
                    case .completion(.cancelled):
                        XCTFail("Should not have cancelled")
                        return .done
                }
            } )
        }

        do {
            let finalDemand = try await t.value
            XCTAssert(finalDemand == .done, "Incorrect return")
        } catch {
            XCTFail("Errored out")
        }
        do {
            try await FreeCombine.wait(for: expectation1, timeout: 10_000_000)
            try await FreeCombine.wait(for: expectation2, timeout: 10_000_000)
        } catch {
            XCTFail("Timed out")
        }

        let _ = await c1.result
    }
}
