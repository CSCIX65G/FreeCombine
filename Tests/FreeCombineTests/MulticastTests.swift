//
//  MulticastTests.swift
//
//
//  Created by Van Simmons on 6/5/22.
//

import XCTest
@testable import FreeCombine

class MulticastTests: XCTestCase {

    override func setUpWithError() throws { }

    override func tearDownWithError() throws { }

    func testSimpleMulticast() async throws {
        let expectation1 = await Expectation<Void>()
        let expectation2 = await Expectation<Void>()

//        let unfolded = await Unfolded(0 ..< 100)
//            .makeConnectable()

        let subject = await PassthroughSubject(Int.self)

        let counter1 = Counter()
        let u1 = await subject.publisher().sink { (result: AsyncStream<Int>.Result) in
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
                    do { try await expectation1.complete() }
                    catch { XCTFail("Failed to complete with error: \(error)") }
                    return .done
                case .completion(.cancelled):
                    XCTFail("Should not have cancelled")
                    return .done
            }
        }

        let counter2 = Counter()
        let u2 = await subject.publisher().sink { (result: AsyncStream<Int>.Result) in
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

        let n = 100
        let upstreamCounter = Counter()
        let upstreamShared = ValueRef<Bool>(value: false)
        let shared = await (0 ..< n)
            .asyncPublisher
            .handleEvents(
                receiveDownstream: { _ in
                    Task<Void, Swift.Error> {
                        guard await upstreamShared.value == false else {
                            XCTFail("Shared more than once")
                            return
                        }
                        await upstreamShared.set(value: true)
                    }
                },
                receiveOutput: { _ in
                    await upstreamCounter.increment()
                },
                receiveFinished: {
                    let count = await upstreamCounter.count
                    XCTAssert(count == n, "Wrong number sent")
                },
                receiveFailure: { error in
                    XCTFail("Inappropriately failed with: \(error)")
                },
                receiveCancel: {
                    XCTFail("Inappropriately cancelled")
                }
            )
            .multicast(subject)
            .sink { value in  }

        let d1 = try await u1.value
        XCTAssert(d1 == .done, "First chain has wrong value")
        let d2 = try await u2.value
        XCTAssert(d2 == .done, "Second chain has wrong value")

        do {
            try await FreeCombine.wait(for: expectation1, timeout: 10_000_000)
            try await FreeCombine.wait(for: expectation2, timeout: 10_000_000)
        } catch {
            XCTFail("Timed out")
        }
        let _ = try await subject.value
        let _ = try await shared.value
    }

//    func testSubjectMulticast() async throws {
//        let subj = await PassthroughSubject(Int.self)
//
//        let connectable = await subj
//            .publisher()
//            .map { $0 }
//            .makeConnectable()
//
//        let counter1 = Counter()
//        let u1 = await connectable.publisher().sink({ result in
//            switch result {
//                case .value:
//                    await counter1.increment()
//                    return .more
//                case let .completion(.failure(error)):
//                    XCTFail("Got an error? \(error)")
//                    return .done
//                case .completion(.finished):
//                    let count = await counter1.count
//                    if count != 100 {
//                        XCTFail("Incorrect count: \(count) in subscription 1")
//                    }
//                    return .done
//                case .completion(.cancelled):
//                    XCTFail("Should not have cancelled")
//                    return .done
//            }
//        })
//
//        let counter2 = Counter()
//        let u2 = await connectable.publisher().sink { (result: AsyncStream<Int>.Result) in
//            switch result {
//                case .value:
//                    await counter2.increment()
//                    return .more
//                case let .completion(.failure(error)):
//                    XCTFail("Got an error? \(error)")
//                    return .done
//                case .completion(.finished):
//                    let count = await counter2.count
//                    if count != 100  {
//                        XCTFail("Incorrect count: \(count) in subscription 2")
//                    }
//                    return .done
//                case .completion(.cancelled):
//                    XCTFail("Should not have cancelled")
//                    return .done
//            }
//        }
//
//        try await connectable.connect()
//
//        for i in (0 ..< 100) {
//            do { try await subj.send(i) }
//            catch { XCTFail("Failed to send on \(i) with error: \(error)") }
//        }
//
//        try await subj.finish()
//        _ = await subj.result
//        _ = await connectable.result
//        let d1 = try await u1.value
//        XCTAssert(d1 == .done, "First chain has wrong value")
//        let d2 = try await u2.value
//        XCTAssert(d2 == .done, "Second chain has wrong value")
//    }
}
