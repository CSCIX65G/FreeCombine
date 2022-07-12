//
//  DebounceTests.swift
//  
//
//  Created by Van Simmons on 7/11/22.
//
import XCTest
@testable import FreeCombine
@testable import Time

class DebounceTests: XCTestCase {
    override func setUpWithError() throws {  }
    override func tearDownWithError() throws { }

    func testSimpleDebounce() async throws {
        let values = ValueRef<[Int]>.init(value: [])
        let inputCounter = Counter()
        let counter = Counter()
        let subject = try await PassthroughSubject(Int.self)
        let t = await subject.publisher()
            .handleEvents(receiveOutput: { _ in await inputCounter.increment() })
            .debounce(interval: .milliseconds(100))
            .sink({ value in
                switch value {
                    case .value(let value):
                        let vals = await values.value
                        await values.set(value: vals + [value])
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
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        try await Task.sleep(nanoseconds: 100_000_000)

        try await subject.finish()
        _ = await subject.result

        let count = await counter.count
        XCTAssert(count == 1, "Got wrong count = \(count)")

        let inputCount = await inputCounter.count
        XCTAssert(inputCount == 15, "Got wrong count = \(inputCount)")

        let vals = await values.value
        XCTAssert(vals == [14], "Incorrect values: \(vals)")

        _ = await t.result
    }

    func testMoreComplexDebounce() async throws {
        let values = ValueRef<[Int]>.init(value: [])
        let inputCounter = Counter()
        let counter = Counter()
        let subject = try await PassthroughSubject(Int.self)
        let t = await subject.publisher()
            .handleEvents(receiveOutput: { _ in await inputCounter.increment() })
            .debounce(interval: .milliseconds(100))
            .sink({ value in
                switch value {
                    case .value(let value):
                        let vals = await values.value
                        await values.set(value: vals + [value])
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
            try await Task.sleep(nanoseconds: i % 2 == 0 ? 50_000_000 : 110_000_000)
        }
        try await Task.sleep(nanoseconds: 100_000_000)

        try await subject.finish()
        _ = await subject.result

        let count = await counter.count
        XCTAssert(count == 8, "Got wrong count = \(count)")

        let inputCount = await inputCounter.count
        XCTAssert(inputCount == 15, "Got wrong count = \(inputCount)")

        let vals = await values.value
        XCTAssert(vals == [1, 3, 5, 7, 9, 11, 13, 14], "Incorrect values: \(vals)")

        _ = await t.result
    }
}
