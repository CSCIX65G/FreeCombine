//
//  ShareTests.swift
//  
//
//  Created by Van Simmons on 6/8/22.
//
import XCTest
@testable import FreeCombine

class AutoconnectTests: XCTestCase {

    override func setUpWithError() throws { }

    override func tearDownWithError() throws { }

    func testSimpleAutoconnect() async throws {
        /*
         p1 and p2 below are NOT guaranteed to see the same number of values bc
         the autoconnected publisher begins publishing as soon as the first subscription
         is connected.  The second subscriber will see only those published
         values that occur after it subscribes.  In some cases it will see zero
         */
        let expectation1 = await Expectation<Void>()
        let expectation2 = await Expectation<Void>()

        let n = 100
        let autoconnected = await (0 ..< n)
            .asyncPublisher
            .map { $0 * 2 }
            .autoconnect(buffering: .bufferingOldest(2))

        let counter1 = Counter()
        let value1 = ValueRef<Int>(value: -1)
        let u1 = await autoconnected.sink({ result in
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
        })

        let counter2 = Counter()
        let value2 = ValueRef<Int>(value: -1)
        let u2 = await autoconnected.sink({ result in
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
                    // NB: the number of values received here is unpredictable
                    // and may be anything 0 ... n
                    let count = await counter2.count
                    XCTAssert(count <= n, "How'd we get so many?")
                    do { try await expectation2.complete() }
                    catch { XCTFail("u2 Failed to complete with error: \(error)") }
                    return .done
                case .completion(.cancelled):
                    let count = await counter2.count
                    let last = await value2.value
                    XCTFail("u2 should not have cancelled, count = \(count), last = \(last)")
                    return .done
            }
        })

        do {
            try await FreeCombine.wait(for: expectation1, timeout: 10_000_000)
        } catch {
            let count = await counter2.count
            let last = await value2.value
            XCTFail("u1 Timed out count = \(count), last = \(last)")
        }

        do {
            try await FreeCombine.wait(for: expectation2, timeout: 10_000_000)
        } catch {
            let count = await counter2.count
            let last = await value2.value
            XCTFail("u2 Timed out count = \(count), last = \(last)")
        }

        let d1 = try await u1.value
        XCTAssert(d1 == .done, "First chain has wrong value")

        let d2 = await u2.cancelAndAwaitResult()
        guard case .success = d2 else {
            XCTFail("Did not get successful result, got: \(d2)")
            return
        }
    }

    func testSimpleShortAutoconnect() async throws {
        /*
         p1 and p2 below are NOT guaranteed to see the same number of values bc
         the autoconnectd publisher begins publishing as soon as the first subscription
         is connected.  The second subscriber will see only those published
         values that occur after it subscribes.  In some cases it will see zero
         */
        let expectation1 = await Expectation<Void>()
        let expectation2 = await Expectation<Void>()

        let n = 1
        let autoconnected = await (0 ..< n)
            .asyncPublisher
            .map { $0 * 2 }
            .autoconnect(buffering: .bufferingOldest(2))

        let counter1 = Counter()
        let value1 = ValueRef<Int>(value: -1)
        let u1 = await autoconnected.sink({ result in
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
        })

        let counter2 = Counter()
        let value2 = ValueRef<Int>(value: -1)
        let u2 = await autoconnected.sink({ result in
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
                    // NB: the number of values received here is unpredictable
                    do { try await expectation2.complete() }
                    catch { XCTFail("u2 Failed to complete with error: \(error)") }
                    return .done
                case .completion(.cancelled):
                    let count = await counter2.count
                    let last = await value2.value
                    XCTFail("u2 should not have cancelled, count = \(count), last = \(last)")
                    return .done
            }
        })

        do {
            try await FreeCombine.wait(for: expectation1, timeout: 10_000_000)
        } catch {
            let count = await counter2.count
            let last = await value2.value
            XCTFail("u1 Timed out count = \(count), last = \(last)")
        }

        do {
            try await FreeCombine.wait(for: expectation2, timeout: 10_000_000)
        } catch {
            let count = await counter2.count
            let last = await value2.value
            XCTFail("u2 Timed out count = \(count), last = \(last)")
        }

        let d1 = try await u1.value
        XCTAssert(d1 == .done, "First chain has wrong value")

        let d2 = await u2.cancelAndAwaitResult()
        guard case .success = d2 else {
            XCTFail("Did not get successful result, got: \(d2)")
            return
        }
    }

    func testSimpleEmptyAutoconnect() async throws {
        /*
         p1 and p2 below are NOT guaranteed to see the same number of values bc
         the autoconnectd publisher begins publishing as soon as the first subscription
         is connected.  The second subscriber will see only those published
         values that occur after it subscribes.  In some cases it will see zero
         */
        let expectation1 = await Expectation<Void>()
        let expectation2 = await Expectation<Void>()

        let n = 0
        let autoconnected = await (0 ..< n)
            .asyncPublisher
            .map { $0 * 2 }
            .autoconnect(buffering: .bufferingOldest(2))

        let counter1 = Counter()
        let value1 = ValueRef<Int>(value: -1)
        let u1 = await autoconnected.sink({ result in
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
        })

        let counter2 = Counter()
        let value2 = ValueRef<Int>(value: -1)
        let u2 = await autoconnected.sink({ result in
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
                    // NB: the number of values received here is unpredictable
                    do { try await expectation2.complete() }
                    catch { XCTFail("u2 Failed to complete with error: \(error)") }
                    return .done
                case .completion(.cancelled):
                    let count = await counter2.count
                    let last = await value2.value
                    XCTFail("u2 should not have cancelled, count = \(count), last = \(last)")
                    return .done
            }
        })

        do {
            try await FreeCombine.wait(for: expectation1, timeout: 10_000_000)
        } catch {
            let count = await counter2.count
            let last = await value2.value
            XCTFail("u1 Timed out count = \(count), last = \(last)")
        }

        do {
            try await FreeCombine.wait(for: expectation2, timeout: 10_000_000)
        } catch {
            let count = await counter2.count
            let last = await value2.value
            XCTFail("u2 Timed out count = \(count), last = \(last)")
        }

        let d1 = try await u1.value
        XCTAssert(d1 == .done, "First chain has wrong value")

        let d2 = await u2.result
        guard case .success = d2 else {
            XCTFail("Did not get successful result, got: \(d2)")
            return
        }
    }
    func testSubjectAutoconnect() async throws {
        /*
         p1 and p2 below should see the same number of values bc
         we set them up before we send to the subject
         */
        let subject = await PassthroughSubject(Int.self)

        /*
         Note that we don't need the `.bufferingOldest(2)` here.  Bc
         we are not trying to simultaneously subscribe and send.
         */
        let publisher = await subject.publisher()
            .map { $0 % 47 }
            .autoconnect()

        let counter1 = Counter()
        let p1 = await publisher.sink( { result in
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
        let p2 = await publisher.sink { (result: AsyncStream<Int>.Result) in
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
            do { try await subject.send(i) }
            catch { XCTFail("Failed to send on \(i)") }
        }

        try await subject.finish()
        let d1 = try await p1.value
        XCTAssert(d1 == .done, "First chain has wrong value")
        let d2 = try await p2.value
        XCTAssert(d2 == .done, "Second chain has wrong value")
        _ = await subject.result
    }
}
