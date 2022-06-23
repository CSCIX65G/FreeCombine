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
        let expectation1 = await Expectation<Void>()
        let expectation2 = await Expectation<Void>()

        let n = 5
        let unfolded = await (0 ..< n)
            .asyncPublisher
            .map { $0 * 2 }
            .share()

        let counter1 = Counter()
        let value1 = ValueRef<Int>(value: -1)
        let u1 = await unfolded.sink { result in
            switch result {
                case let .value(value):
                    await counter1.increment()
                    await value1.set(value: value)
                    return .more
                case let .completion(.failure(error)):
                    XCTFail("Got an error? \(error)")
                    return .done
                case .completion(.finished):
                    let count = await counter1.count
                    guard count == n else {
                        XCTFail("Incorrect count: \(count) in subscription 1")
                        return .done
                    }
                    do { try await expectation1.complete() }
                    catch { XCTFail("u1 Failed to complete with error: \(error)") }
                    return .done
                case .completion(.cancelled):
                    XCTFail("u1 should not have cancelled")
                    return .done
            }
        }

        let counter2 = Counter()
        let value2 = ValueRef<Int>(value: -1)
        let u2 = await unfolded.sink { result in
            switch result {
                case let .value(value):
                    await counter2.increment()
                    await value2.set(value: value)
                    return .more
                case let .completion(.failure(error)):
                    XCTFail("u2 completed with error: \(error)")
                    do { try await expectation2.complete() }
                    catch { XCTFail("u2 Failed to complete with error: \(error)") }
                    return .done
                case .completion(.finished):
                    // Note number received here is unpredictable
                    do { try await expectation2.complete() }
                    catch { XCTFail("u2 Failed to complete with error: \(error)") }
                    return .done
                case .completion(.cancelled):
                    let count = await counter2.count
                    let last = await value2.value
                    XCTFail("u2 should not have cancelled, count = \(count), last = \(last)")
                    return .done
            }
        }

        do {
            try await FreeCombine.wait(for: expectation1, timeout: 200_000_000)
        } catch {
            let count = await counter2.count
            let last = await value2.value
            XCTFail("u1 Timed out count = \(count), last = \(last)")
        }

        do {
            try await FreeCombine.wait(for: expectation2, timeout: 200_000_000)
        } catch {
            let count = await counter2.count
            let last = await value2.value
            XCTFail("u2 Timed out count = \(count), last = \(last)")
        }

        let d1 = try await u1.value
        XCTAssert(d1 == .done, "First chain has wrong value")

        let d2 = try await u2.value
        XCTAssert(d2 == .done, "Second chain has wrong value")
    }

    func testSubjectShare() async throws {
        let subj = await PassthroughSubject(Int.self)

        let publisher = await subj.publisher()
            .map { $0 % 47 }
            .share()

        let counter1 = Counter()
        let u1 = await publisher.sink( { result in
            switch result {
                case .value:
                    await counter1.increment()
                    return .more
                case let .completion(.failure(error)):
                    XCTFail("Got an error? \(error)")
                    return .done
                case .completion(.finished):
                    let count = await counter1.count
                    if count != 100 {
                        XCTFail("Incorrect count: \(count) in subscription 1")
                    }
                    return .done
                case .completion(.cancelled):
                    XCTFail("Should not have cancelled")
                    return .done
            }
        })

        let counter2 = Counter()
        let u2 = await publisher.sink { (result: AsyncStream<Int>.Result) in
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
