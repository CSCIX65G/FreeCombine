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
            try await subject.finish()
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
            try await subject.finish()
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

    func testSimpleCancellation() async throws {
        let counter = Counter()
        let expectation = await CheckedExpectation<Void>(name: "expectation")
        let expectation2 = await CheckedExpectation<Void>(name: "expectation2")
        let release = await CheckedExpectation<Void>(name: "release")

        let subject = await PassthroughSubject(type: Int.self, buffering: .unbounded)
        let p = subject.publisher(
            onCancel: { Task { try await expectation2.complete() } }
        )

        let can = await p.sink({ result in
            switch result {
                case let .value(value):
                    let count = await counter.increment()
                    XCTAssertEqual(value, count, "Wrong value sent")
                    if count == 8 {
                        do { try await expectation.complete() }
                        catch {  XCTFail("failed to complete") }
                        do {
                            try await FreeCombine.wait(for: release, timeout: 10_000_000)
                        } catch {
                            guard let error = error as? PublisherError, case error = PublisherError.cancelled else {
                                XCTFail("Timed out waiting for release")
                                return .done
                            }
                        }
                    } else if count > 8 {
                        if !Task.isCancelled { XCTFail("Should be cancelled") }
                        XCTFail("Got value after cancellation")
                    }
                    return .more
                case let .completion(.failure(error)):
                    XCTFail("Should not have gotten error: \(error)")
                    return .done
                case .completion(.finished):
                    return .done
            }
        })

        await Task.yield()
        for i in 1 ... 7 {
            do { try await subject.send(i) }
            catch { XCTFail("Failed to enqueue") }
        }

        do { try subject.nonBlockingSend(8) }
        catch { XCTFail("Failed to enqueue") }

        do { try await FreeCombine.wait(for: expectation, timeout: 100_000_000) }
        catch { XCTFail("Failed waiting for expectation") }

        can.cancel()
        try await release.complete()

        do {
            try await subject.send(9)
            try await subject.send(10)
        } catch {
            XCTFail("Failed to enqueue")
        }
        try await subject.finish()

        do {
            try await FreeCombine.wait(for: expectation2, timeout: 100_000_000)
        } catch {
            XCTFail("Timed out")
        }
    }

//    func testSimpleTermination() async throws {
//            let counter = Counter()
//            let expectation = await CheckedExpectation<Void>()
//
//            let subject: Subject<Int> = .init()
//            let p = subject.publisher()
//
//            _ = await p.subscribe { result in
//                switch result {
//                    case let .value(value):
//                        let count = await counter.increment()
//                        XCTAssertEqual(value, count, "Wrong value sent")
//                        return .more
//                    case let .failure(error):
//                        XCTFail("Should not have gotten error: \(error)")
//                        return .done
//                    case .terminated:
//                        do { try await expectation.complete() }
//                        catch { XCTFail("Failed to complete expectation") }
//                        return .done
//                }
//            }
//
//            await Task.yield()
//            for i in 1 ... 1000 {
//                do { try subject.send(i) }
//                catch { XCTFail("Failed to enqueue") }
//            }
//            subject.finish()
//
//            do {
//                try await FreeCombine.wait(for: expectation, timeout: 50_000_000)
//            } catch {
//                let count = await counter.count
//                XCTFail("Timed out waiting for expectation.  processed: \(count)")
//            }
//        }
//
//        func testSimpleSubjectSend() async throws {
//            let counter = Counter()
//            let expectation = await CheckedExpectation<Void>()
//
//            let subject: Subject<Int> = .init()
//            let p = subject.publisher()
//
//            _ = await p.subscribe { result in
//                switch result {
//                    case let .value(value):
//                        let count = await counter.increment()
//                        XCTAssertEqual(value, count, "Wrong value sent")
//                        return .more
//                    case let .failure(error):
//                        XCTFail("Should not have gotten error: \(error)")
//                        return .done
//                    case .terminated:
//                        do { try await expectation.complete() }
//                        catch { XCTFail("Could not complete, error: \(error)") }
//                        return .done
//                }
//            }
//
//            await Task.yield()
//            (1 ... 5).forEach {
//                do {  try subject.send($0) }
//                catch { XCTFail("Failed to enqueue") }
//            }
//            subject.finish()
//
//            await Task.yield()
//            do {
//                try await FreeCombine.wait(for: expectation, timeout: 10_000_000)
//            } catch {
//                let count = await counter.count
//                XCTFail("Timed out waiting for expectation.  processed: \(count)")
//            }
//        }
//
//        func testSyncAsync() async throws {
//            let expectation = await CheckedExpectation<Void>()
//            let fsubject1 = await FreeCombine.PassthroughSubject(Int.self)
//            let fsubject2 = await FreeCombine.PassthroughSubject(String.self)
//
//            let fseq1 = "abcdefghijklmnopqrstuvwxyz".asyncPublisher
//            let fseq2 = (1 ... 100).asyncPublisher
//
//            let fz1 = fseq1.zip(fseq2)
//            let fz2 = fz1
//                .map { left, right in String(left) + String(right) }
//
//            let fm1 = fsubject1.publisher()
//                .map(String.init)
//                .mapError { _ in fatalError() }
//                .merge(with: fsubject2.publisher())
//                .replaceError(with: "")
//
//            let fm2 = fz2.merge(with: fm1)
//            _ = await fm2.subscribe { value in
//                guard case .terminated = value else {
//                    do {
//                        if case let .value(value) = value, value == "hello, combined world!" {
//                            try await expectation.complete()
//                        }
//                    }
//                    catch { XCTFail("Should not have failed termination: \(error)") }
//                    return .more
//                }
//                return .done
//            }
//
//            try fsubject1.send(14)
//            try fsubject2.send("hello, combined world!")
//
//            fsubject1.finish()
//            fsubject2.finish()
//
//            do { try await FreeCombine.wait(for: expectation, timeout: 1_000_000) }
//            catch { XCTFail("timed out") }
//        }
//
//    }

}
