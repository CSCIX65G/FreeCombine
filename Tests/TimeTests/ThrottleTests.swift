//
//  ThrottleTests.swift
//  
//
//  Created by Van Simmons on 7/5/22.
//

import XCTest
@testable import FreeCombine
@testable import Time

class ThrottleTests: XCTestCase {

    override func setUpWithError() throws { }

    override func tearDownWithError() throws { }

    func testSimpleThrottle() async throws {
        let expectation = await Expectation<Void>()

        let inputCounter = Counter()
        let counter = Counter()
        let t = await (1 ... 15).asyncPublisher
            .handleEvents(receiveOutput: { _ in await inputCounter.increment() })
            .throttle(interval: .milliseconds(1000), latest: false)
            .sink({ value in
                switch value {
                    case .value(_):
                        await counter.increment()
                        return .more
                    case let .completion(.failure(error)):
                        XCTFail("Got unexpected failure: \(error)")
                        return .done
                    case .completion(.finished):
                        return .done
                    case .completion(.cancelled):
                        return .done
                }
            })

        do {
            try await FreeCombine.wait(for: expectation, timeout: 1_000_000_000)
        } catch {
            t.cancel()
            let count = await counter.count
            let inputCount = await inputCounter.count
            XCTAssert(count == 1, "Got wrong count = \(count)")
            XCTAssert(inputCount == 15, "Got wrong count = \(inputCount)")
        }

        _ = await t.result
    }

    func testSimpleSubjectThrottle() async throws {
        let inputCounter = Counter()
        let counter = Counter()
        let subject = try await PassthroughSubject(Int.self)
        let t = await subject.publisher()
            .handleEvents(receiveOutput: { _ in await inputCounter.increment() })
            .throttle(interval: .milliseconds(1000), latest: false)
            .sink({ value in
                switch value {
                    case .value(let value):
                        print(value)
                        await counter.increment()
                        return .more
                    case let .completion(.failure(error)):
                        XCTFail("Got unexpected failure: \(error)")
                        return .done
                    case .completion(.finished):
                        return .done
                    case .completion(.cancelled):
                        XCTFail("Should not have cancelled")
                        return .done
                }
            })

        for i in (0 ..< 15) {
            try await subject.send(i)
            try await Task.sleep(nanoseconds: 100_000_000)
        }

        try await subject.finish()
        _ = await subject.result

        let count = await counter.count
        XCTAssert(count == 2, "Got wrong count = \(count)")

        let inputCount = await inputCounter.count
        XCTAssert(inputCount == 15, "Got wrong count = \(inputCount)")

        _ = await t.result
    }

    func testSimpleSubjectThrottleLatest() async throws {
        let inputCounter = Counter()
        let counter = Counter()
        let subject = try await PassthroughSubject(Int.self)
        let t = await subject.publisher()
            .handleEvents(receiveOutput: { _ in await inputCounter.increment() })
            .throttle(interval: .milliseconds(1000), latest: true)
            .sink({ value in
                switch value {
                    case .value(let value):
                        print(value)
                        await counter.increment()
                        return .more
                    case let .completion(.failure(error)):
                        XCTFail("Got unexpected failure: \(error)")
                        return .done
                    case .completion(.finished):
                        return .done
                    case .completion(.cancelled):
                        XCTFail("Should not have cancelled")
                        return .done
                }
            })

        for i in (0 ..< 15) {
            try await subject.send(i)
            try await Task.sleep(nanoseconds: 100_000_000)
        }

        try await subject.finish()
        _ = await subject.result

        let count = await counter.count
        XCTAssert(count == 2, "Got wrong count = \(count)")

        let inputCount = await inputCounter.count
        XCTAssert(inputCount == 15, "Got wrong count = \(inputCount)")

        _ = await t.result
    }
}
