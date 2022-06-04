//
//  MergeTests.swift
//
//
//  Created by Van Simmons on 2/1/22.
//

import XCTest
@testable import FreeCombine

class MergeTests: XCTestCase {

    override func setUpWithError() throws { }

    override func tearDownWithError() throws { }

    func testSimpleMerge() async throws {
        let expectation = await CheckedExpectation<Void>()

        let publisher1 = "01234567890123".asyncPublisher
        let publisher2 = "abcdefghijklmnopqrstuvwxyz".asyncPublisher
        let publisher3 = "abcdefghijklmnopqrstuvwxyz".reversed().asyncPublisher

        let counter = Counter()
        let m1 = await merge(publishers: publisher1, publisher2, publisher3)
            .map { $0.uppercased() }
            .sink({ result in
                switch result {
                    case .value:
                        await counter.increment()
                        return .more
                    case let .completion(.failure(error)):
                        XCTFail("Got an error? \(error)")
                        return .done
                    case .completion(.finished):
                        let count = await counter.count
                        XCTAssert(count == 66, "wrong number of values sent: \(count)")
                        do { try await expectation.complete() }
                        catch { XCTFail("Failed to complete with error: \(error)") }
                        return .done
                    case .completion(.cancelled):
                        XCTFail("Should not have cancelled")
                        return .done
                }
            })

        do {  try await FreeCombine.wait(for: expectation, timeout: 100_000_000) }
        catch { XCTFail("Timed out") }
        
        do { let _ = try await m1.value }
        catch {
            XCTFail("Should have gotten value")
        }
    }

    func testInlineMerge() async throws {
        let expectation = await CheckedExpectation<Void>()

        let fseq1 = (101 ... 150).asyncPublisher
        let fseq2 = (1 ... 100).asyncPublisher

        let fm1 = Merged(fseq1, fseq2)

        let c1 = await fm1
            .sink({ value in
                switch value {
                    case .value(_):
                        return .more
                    case let .completion(.failure(error)):
                        XCTFail("Should not have received failure: \(error)")
                        return .done
                    case .completion(.finished):
                        try await expectation.complete()
                        return .done
                    case .completion(.cancelled):
                        XCTFail("Should not have cancelled")
                        return .done
                }
            })

        do { try await FreeCombine.wait(for: expectation, timeout: 10_000_000_000) }
        catch {
            XCTFail("timed out")
        }
        c1.cancel()
    }
}
