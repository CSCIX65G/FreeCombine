//
//  CancellationTests.swift
//  
//
//  Created by Van Simmons on 5/15/22.
//

import XCTest
@testable import FreeCombine

class CancellationTests: XCTestCase {

    override func setUpWithError() throws { }

    override func tearDownWithError() throws { }

    func testSimpleZipCancellation() async throws {
        let expectation = await CheckedExpectation<Void>()
        let waiter = await CheckedExpectation<Void>()

        let canRight: @Sendable () -> Void = {
            Task {
                do { try await expectation.complete() }
                catch { XCTFail("Failed to complete: \(error)") }
            }
        }

        let publisher1 = (0 ... 100).asyncPublisher
        let publisher2 = "abcdefghijklmnopqrstuvwxyz".asyncPublisher

        let counter = Counter()
        let z2 = await zip(onCancel: canRight, publisher1, publisher2)
            .map { ($0.0 + 100, $0.1.uppercased()) }
            .sink { (result: AsyncStream<(Int, String)>.Result) in
                switch result {
                    case .value:
                        let count = await counter.increment()
                        if count > 9 { try? await waiter.value(); return .more }
                        if Task.isCancelled {
                            XCTFail("Got values after cancellation")
                            do { try await expectation.complete() }
                            catch { XCTFail("Failed to complete: \(error)") }
                            return .done
                        }
                    case let .completion(.failure(error)):
                        XCTFail("Got an error? \(error)")
                    case .completion(.finished):
                        XCTFail("Got to end of task that should have been cancelled")
                        do { try await expectation.complete() }
                        catch { XCTFail("Failed to complete: \(error)") }
                        return .done
                }
                return .more
            }
        await Task.yield()
        // Sleep 1ms to allow several values to be sent
        try await Task.sleep(nanoseconds: 1_000_000)
        z2.cancel()
        await Task.yield()

        do { try await FreeCombine.wait(for: expectation, timeout: 100_000_000) }
        catch { XCTFail("Timed out with count: \(await counter.count)") }
    }
}
