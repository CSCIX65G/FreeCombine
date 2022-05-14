//
//  File.swift
//  
//
//  Created by Van Simmons on 5/13/22.
//
import XCTest
@testable import FreeCombine

class SubjectTests: XCTestCase {

    override func setUpWithError() throws { }

    override func tearDownWithError() throws { }

    func xtestSimpleSubject() async throws {
        let expectation = await CheckedExpectation<Void>()

        let subject = await PassthroughSubject(
            type: Int.self,
            buffering: .unbounded
        )

        let publisher1 = subject.publisher()

        let counter = Counter()

        _ = await publisher1.sink { (result: AsyncStream<Int>.Result) in
            let count = await counter.count
            switch result {
                case let .value(value):
                    _ = await counter.increment()
                    print(value)
                case let .completion(.failure(error)):
                    XCTFail("Got an error? \(error)")
                case .completion(.finished):
                    XCTAssert(count == 1, "wrong number of values sent: \(count)")
                    do {  try await expectation.complete() }
                    catch { XCTFail("Failed to complete: \(error)") }
                    return .done
            }
            return .more
        }
        try await subject.send(14)

        do { try await FreeCombine.wait(for: expectation, timeout: 100_000_000) }
        catch {
            let count = await counter.count
            XCTFail("Timed out, count = \(count)")
        }
    }
}
