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
        let expectation = await Expectation<Void>()

        let subject = try await CurrentValueSubject(currentValue: 14)
        let publisher = subject.publisher()

        let counter = Counter()
        let c1 = await publisher.sink { (result: AsyncStream<Int>.Result) in
            let count = await counter.count
            switch result {
                case .value:
                    _ = await counter.increment()
                    return .more
                case let .completion(.failure(error)):
                    XCTFail("Got an error? \(error)")
                    return .done
                case .completion(.finished):
                    XCTAssert(count == 5, "wrong number of values sent: \(count)")
                    do {
                        try await expectation.complete()
                    }
                    catch {
                        XCTFail("Failed to complete: \(error)")
                    }
                    return .done
                case .completion(.cancelled):
                    XCTFail("Should not have cancelled")
                    return .done
            }
        }
        do {
            try await subject.send(14)
            try await subject.send(15)
            try await subject.send(16)
            try await subject.send(17)
            try await subject.finish()
        } catch {
            XCTFail("Caught error: \(error)")
        }

        do { _ =
            try await subject.value
            let demand = try await c1.value
            XCTAssert(demand == .done, "Did not finish correctly")
        }
        catch { XCTFail("Should not have thrown") }
        do {
            try await FreeCombine.wait(for: expectation, timeout: 10_000_000)
        }
        catch {
            let count = await counter.count
            XCTFail("Timed out, count = \(count)")
        }

        _ = await c1.result
        _ = await subject.result
    }

    func testMultisubscriptionSubject() async throws {
        let expectation1 = await Expectation<Void>()
        let expectation2 = await Expectation<Void>()

        let subject = try await CurrentValueSubject(currentValue: 14)
        let publisher = subject.publisher()

        let counter1 = Counter()
        let c1 = await publisher.sink { (result: AsyncStream<Int>.Result) in
            let count = await counter1.count
            switch result {
                case .value:
                    _ = await counter1.increment()
                    return .more
                case let .completion(.failure(error)):
                    XCTFail("Got an error? \(error)")
                    return .done
                case .completion(.finished):
                    XCTAssert(count == 5, "wrong number of values sent: \(count)")
                    do { try await expectation1.complete() }
                    catch { XCTFail("Failed to complete: \(error)") }
                    return .done
                case .completion(.cancelled):
                    XCTFail("Should not have cancelled")
                    return .done
            }
        }

        let counter2 = Counter()
        let c2 = await publisher.sink { (result: AsyncStream<Int>.Result) in
            let count = await counter2.count
            switch result {
                case .value:
                    _ = await counter2.increment()
                    return .more
                case let .completion(.failure(error)):
                    XCTFail("Got an error? \(error)")
                    return .done
                case .completion(.finished):
                    XCTAssert(count == 5, "wrong number of values sent: \(count)")
                    do { try await expectation2.complete() }
                    catch { XCTFail("Failed to complete: \(error)") }
                    return .done
                case .completion(.cancelled):
                    XCTFail("Should not have cancelled")
                    return .done
            }
        }

        do {
            try await subject.send(14)
            try await subject.send(15)
            try await subject.send(16)
            try await subject.send(17)
            try await subject.finish()
        } catch {
            XCTFail("Caught error: \(error)")
        }

        do { _ =
            try await subject.value
            let demand1 = try await c1.value
            XCTAssert(demand1 == .done, "Did not finish c1 correctly")
            let demand2 = try await c2.value
            XCTAssert(demand2 == .done, "Did not finish c2 correctly")
        }
        catch { XCTFail("Should not have thrown") }
        do {
            try await FreeCombine.wait(for: expectation1, timeout: 10_000_000)
            try await FreeCombine.wait(for: expectation2, timeout: 10_000_000)
        }
        catch {
            let count1 = await counter1.count
            let count2 = await counter2.count
            XCTFail("Timed out, count1 = \(count1), count2 = \(count2)")
        }
        _ = await c1.result
        _ = await c2.result
        _ = await subject.result
    }

    func testSimpleCancellation() async throws {
        let counter = Counter()
        let expectation = await Expectation<Void>()
        let expectation3 = await Expectation<Void>()
        let release = await Expectation<Void>()

        let subject = try await PassthroughSubject(Int.self)
        let p = subject.publisher()

        let can = await p.sink({ result in
            switch result {
                case let .value(value):
                    let count = await counter.increment()
                    XCTAssertEqual(value, count, "Wrong value sent")
                    if count == 8 {
                        do {
                            try await expectation.complete()
                            return .more
                        }
                        catch {
                            XCTFail("failed to complete")
                        }
                        do {
                            try await release.value
                            return .more
                        } catch {
                            guard let error = error as? PublisherError, case error = PublisherError.cancelled else {
                                XCTFail("Timed out waiting for release")
                                return .done
                            }
                        }
                    } else if count > 8 {
                        XCTFail("Got value after cancellation")
                        return .done
                    }
                    return .more
                case let .completion(.failure(error)):
                    XCTFail("Should not have gotten error: \(error)")
                    return .done
                case .completion(.finished):
                    XCTFail("Should not have finished")
                    return .done
                case .completion(.cancelled):
                    try await expectation3.complete()
                    return .done
            }
        })

        for i in 1 ... 7 {
            do { try await subject.send(i) }
            catch { XCTFail("Failed to enqueue") }
        }

        do { try await subject.send(8) }
        catch { XCTFail("Failed to enqueue") }

        do { try await FreeCombine.wait(for: expectation, timeout: 10_000_000) }
        catch { XCTFail("Failed waiting for expectation") }

        let _ = can.cancel()

        try await release.complete()
        do {
            try await FreeCombine.wait(for: expectation3, timeout: 10_000_000)
        } catch {
            XCTFail("Failed waiting for expectation3")
        }

        do {
            try await subject.send(9)
            try await subject.send(10)
        } catch {
            XCTFail("Failed to enqueue")
        }
        try await subject.finish()
        _ = await subject.result
    }

    func testSimpleTermination() async throws {
        let counter = Counter()
        let expectation = await Expectation<Void>()

        let subject = try await PassthroughSubject(Int.self)
        let p = subject.publisher()

        let c1 = await p.sink( { result in
            switch result {
                case let .value(value):
                    let count = await counter.increment()
                    XCTAssertEqual(value, count, "Wrong value sent")
                    return .more
                case let .completion(.failure(error)):
                    XCTFail("Should not have gotten error: \(error)")
                    return .done
                case .completion(.finished):
                    do { try await expectation.complete() }
                    catch { XCTFail("Failed to complete expectation") }
                    let count = await counter.count
                    XCTAssert(count == 1000, "Received wrong number of invocations: \(count)")
                    return .done
                case .completion(.cancelled):
                    XCTFail("Should not have cancelled")
                    return .done
            }
        })

        for i in 1 ... 1000 {
            do { try await subject.send(i) }
            catch { XCTFail("Failed to enqueue") }
        }
        try await subject.finish()

        do {
            try await FreeCombine.wait(for: expectation, timeout: 50_000_000)
        } catch {
            let count = await counter.count
            XCTFail("Timed out waiting for expectation.  processed: \(count)")
        }
        _ = await c1.result
        _ = await subject.result
    }

    func testSimpleSubjectSend() async throws {
        let counter = Counter()
        let expectation = await Expectation<Void>()

        let subject = try await PassthroughSubject(Int.self)
        let p = subject.publisher()

        let c1 = await p.sink({ result in
            switch result {
                case let .value(value):
                    let count = await counter.increment()
                    XCTAssertEqual(value, count, "Wrong value sent")
                    return .more
                case let .completion(.failure(error)):
                    XCTFail("Should not have gotten error: \(error)")
                    return .done
                case .completion(.finished):
                    do { try await expectation.complete() }
                    catch { XCTFail("Could not complete, error: \(error)") }
                    let count = await counter.count
                    XCTAssert(count == 5, "Received wrong number of invocations: \(count)")
                    return .done
                case .completion(.cancelled):
                    XCTFail("Should not have cancelled")
                    return .done
            }
        })

        for i in (1 ... 5) {
            do { try await subject.send(i) }
            catch { XCTFail("Failed to enqueue") }
        }
        try await subject.finish()

        do {
            try await FreeCombine.wait(for: expectation, timeout: 10_000_000)
        } catch {
            let count = await counter.count
            XCTFail("Timed out waiting for expectation.  processed: \(count)")
        }
        _ = await c1.result
        _ = await subject.result
    }

    func testSyncAsync() async throws {
        let expectation = await Expectation<Void>()
        let fsubject1 = try await FreeCombine.PassthroughSubject(Int.self)
        let fsubject2 = try await FreeCombine.PassthroughSubject(String.self)
        
        let fseq1 = "abcdefghijklmnopqrstuvwxyz".asyncPublisher
        let fseq2 = (1 ... 100).asyncPublisher

        let fz1 = fseq1.zip(fseq2)
        let fz2 = fz1.map { left, right in String(left) + String(right) }

        let fm1 = fsubject1.publisher()
            .map(String.init)
            .merge(with: fsubject2.publisher())

        let counter = Counter()
        let c1 = await fz2
            .merge(with: fm1)
            .sink({ value in
                switch value {
                    case .value(_):
                        await counter.increment()
                        return .more
                    case let .completion(.failure(error)):
                        XCTFail("Should not have received failure: \(error)")
                        return .done
                    case .completion(.finished):
                        let count = await counter.count
                        if count != 28  { XCTFail("Incorrect number of values") }
                        try await expectation.complete()
                        return .done
                    case .completion(.cancelled):
                        XCTFail("Should not have cancelled")
                        return .done
                }
            })

        try await fsubject1.send(14)
        try await fsubject2.send("hello, combined world!")

        try await fsubject1.finish()
        try await fsubject2.finish()

        do { try await FreeCombine.wait(for: expectation, timeout: 200_000_000) }
        catch {
            XCTFail("timed out")
        }
        do { _ = try await c1.value }
        catch { XCTFail("Should have completed normally") }

        _ = await fsubject1.result
        _ = await fsubject2.result

    }
}
