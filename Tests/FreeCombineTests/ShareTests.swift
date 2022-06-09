//
//  ShareTests.swift
//  
//
//  Created by Van Simmons on 6/8/22.
//
import XCTest
@testable import FreeCombine

class ShareTests: XCTestCase {

    override func setUpWithError() throws { }

    override func tearDownWithError() throws { }

    func testSimpleShare() async throws {
        let expectation1 = await CheckedExpectation<Void>()
        let expectation2 = await CheckedExpectation<Void>()

        let unfolded = await Unfolded(0 ..< 100)
            .map { $0 % 47 }
            .share()

        let counter1 = Counter()
        let u1 = await unfolded.sink { (result: AsyncStream<Int>.Result) in
            print("Result 1: \(result)")
            switch result {
                case .value:
                    await counter1.increment()
                    return .more
                case let .completion(.failure(error)):
                    XCTFail("Got an error? \(error)")
                    return .done
                case .completion(.finished):
                    let count = await counter1.count
                    guard count == 100 else {
                        XCTFail("Incorrect count: \(count) in subscription 1")
                        return .done
                    }
                    do {
                        try await expectation1.complete()
                    }
                    catch { XCTFail("Failed to complete with error: \(error)") }
                    return .done
                case .completion(.cancelled):
                    XCTFail("Should not have cancelled")
                    return .done
            }
        }

        let counter2 = Counter()
        let u2 = await unfolded.sink { (result: AsyncStream<Int>.Result) in
            print("Result 2: \(result)")
            switch result {
                case .value:
                    await counter2.increment()
                    return .more
                case let .completion(.failure(error)):
                    XCTFail("Got an error? \(error)")
                    return .done
                case .completion(.finished):
                    let count = await counter2.count
                    guard count == 100 else {
                        XCTFail("Incorrect count: \(count) in subscription 2")
                        return .done
                    }
                    do { try await expectation2.complete() }
                    catch { XCTFail("Failed to complete with error: \(error)") }
                    return .done
                case .completion(.cancelled):
                    XCTFail("Should not have cancelled")
                    return .done
            }
        }

        do {
            try await FreeCombine.wait(for: expectation1, timeout: 100_000_000)
        } catch {
            XCTFail("Timed out")
        }

        print("Waiting on u1")
        let d1 = try await u1.value
        XCTAssert(d1 == .done, "First chain has wrong value")

        do {
            try await FreeCombine.wait(for: expectation2, timeout: 100_000_000)
        } catch {
            XCTFail("Timed out")
        }
        print("Waiting on u2")
        let d2 = try await u2.value
        XCTAssert(d2 == .done, "Second chain has wrong value")
    }

    func testSubjectMulticast() async throws {
        let subj = await PassthroughSubject(Int.self)

        let unfolded = await subj
            .publisher()
            .map { $0 % 47 }
            .multicast()

        let counter1 = Counter()
        let u1 = await unfolded.publisher().sink( { result in
            switch result {
                case .value:
                    await counter1.increment()
                    return .more
                case let .completion(.failure(error)):
                    XCTFail("Got an error? \(error)")
                    return .done
                case .completion(.finished):
                    print("received: \(result)")
                    let count = await counter1.count
                    if count != 100 {
                        XCTFail("Incorrect count: \(count) in subscription 1")
                    }
                    return .done
                case .completion(.cancelled):
                    print("received: \(result)")
                    XCTFail("Should not have cancelled")
                    return .done
            }
        })

        let counter2 = Counter()
        let u2 = await unfolded.publisher().sink { (result: AsyncStream<Int>.Result) in
            switch result {
                case .value:
                    await counter2.increment()
                    return .more
                case let .completion(.failure(error)):
                    XCTFail("Got an error? \(error)")
                    return .done
                case .completion(.finished):
                    let count = await counter2.count
                    if count != 100  {
                        XCTFail("Incorrect count: \(count) in subscription 2")
                    }
                    return .done
                case .completion(.cancelled):
                    XCTFail("Should not have cancelled")
                    return .done
            }
        }

        try await unfolded.connect()

        for i in (0 ..< 100) {
            do { try await subj.send(i) }
            catch { XCTFail("Failed to send on \(i)") }
        }

        try subj.nonBlockingFinish()
        let d1 = try await u1.value
        XCTAssert(d1 == .done, "First chain has wrong value")
        let d2 = try await u2.value
        XCTAssert(d2 == .done, "Second chain has wrong value")
    }
}
