//
//  SubjectTests.swift
//  
//
//  Created by Van Simmons on 5/13/22.
//
import XCTest
@testable import FreeCombine

class SubjectTests: XCTestCase {

    override func setUpWithError() throws { }

    override func tearDownWithError() throws { }

    func testSimpleSubject() async throws {
        let expectation = await CheckedExpectation<Void>()

        let subject = await CurrentValueSubject(
            currentValue: 14,
            buffering: .unbounded
        )

        let publisher1 = subject.publisher()

        let counter = Counter()

        _ = await publisher1.sink { (result: AsyncStream<Int>.Result) in
            let count = await counter.count
            switch result {
                case .value:
                    _ = await counter.increment()
                case let .completion(.failure(error)):
                    XCTFail("Got an error? \(error)")
                case .completion(.finished):
                    XCTAssert(count == 5, "wrong number of values sent: \(count)")
                    do {
                        try await expectation.complete()
                    }
                    catch { XCTFail("Failed to complete: \(error)") }
                    return .done
            }
            return .more
        }
        do {
            try await subject.send(14)
            try await subject.send(15)
            try await subject.send(16)
            try await subject.send(17)
            try await subject.complete()
        } catch {
            XCTFail("Caught error: \(error)")
        }

        do { try await FreeCombine.wait(for: expectation, timeout: 100_000_000) }
        catch {
            let count = await counter.count
            XCTFail("Timed out, count = \(count)")
        }
    }

    func testMultisubscriptionSubject() async throws {
        let expectation1 = await CheckedExpectation<Void>()
        let expectation2 = await CheckedExpectation<Void>()

        let subject = await CurrentValueSubject(currentValue: 14)
        let publisher = subject.publisher()

        let counter1 = Counter()
        _ = await publisher.sink { (result: AsyncStream<Int>.Result) in
            let count = await counter1.count
            switch result {
                case .value:
                    _ = await counter1.increment()
                case let .completion(.failure(error)):
                    XCTFail("Got an error? \(error)")
                case .completion(.finished):
                    XCTAssert(count == 5, "wrong number of values sent: \(count)")
                    do { try await expectation1.complete() }
                    catch { XCTFail("Failed to complete: \(error)") }
                    return .done
            }
            return .more
        }

        let counter2 = Counter()
        _ = await publisher.sink { (result: AsyncStream<Int>.Result) in
            let count = await counter2.count
            switch result {
                case .value:
                    _ = await counter2.increment()
                case let .completion(.failure(error)):
                    XCTFail("Got an error? \(error)")
                case .completion(.finished):
                    XCTAssert(count == 5, "wrong number of values sent: \(count)")
                    do { try await expectation2.complete() }
                    catch { XCTFail("Failed to complete: \(error)") }
                    return .done
            }
            return .more
        }

        do {
            try await subject.send(14)
            try await subject.send(15)
            try await subject.send(16)
            try await subject.send(17)
            try await subject.complete()
        } catch {
            XCTFail("Caught error: \(error)")
        }

        do {
            try await FreeCombine.wait(
                for: [expectation1, expectation2],
                timeout: 100_000_000,
                reducing: (),
                with: { _, _ in }
            )
        }
        catch {
            XCTFail("Timed out")
        }
    }
}
