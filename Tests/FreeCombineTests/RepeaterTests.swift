//
//  RepeaterTests.swift
//  
//
//  Created by Van Simmons on 5/13/22.
//

import XCTest
@testable import FreeCombine

class RepeaterTests: XCTestCase {

    override func setUpWithError() throws { }

    override func tearDownWithError() throws { }

    func testSimpleRepeater() async throws {
        let expectation = await CheckedExpectation<Void>()
        let downstream: @Sendable (AsyncStream<Int>.Result) async throws -> Demand = { result in
            switch result {
                case .value:
                    return .more
                case .completion:
                    try await expectation.complete()
                    return .done
            }
        }
        let nextKey = 1
        let _: Void = await withUnsafeContinuation { continuation in
            Task {
                let repeaterState = await RepeaterState(id: nextKey, downstream: downstream)
                let repeater: StateTask<RepeaterState<Int, Int>, RepeaterState<Int, Int>.Action> = .init(
                    channel: .init(buffering: .bufferingOldest(1)),
                    initialState: {_ in repeaterState },
                    onStartup: continuation,
                    reducer: Reducer(reducer: RepeaterState.reduce)
                )
                await withUnsafeContinuation { (completedContinuation: UnsafeContinuation<[Int], Never>) in
                    let semaphore = Semaphore.init(
                        continuation: completedContinuation,
                        reducer: { (completedIds: inout [Int], action: RepeatedAction<Int>) in
                            guard case let .repeated(id, .done) = action else { return }
                            completedIds.append(id)
                        },
                        initialState: [Int](),
                        count: 1
                    )
                    let queueStatus = repeater.send(.repeat(.value(14), semaphore))
                    guard case .enqueued = queueStatus else {
                        fatalError("Internal failure in Repeater reducer processing key, queueStatus: \(queueStatus)")
                    }
                }.forEach { key in fatalError("should not have key") }

                await withUnsafeContinuation { (completedContinuation: UnsafeContinuation<[Int], Never>) in
                    let semaphore = Semaphore.init(
                        continuation: completedContinuation,
                        reducer: { (completedIds: inout [Int], action: RepeatedAction<Int>) in
                            guard case let .repeated(id, .done) = action else { return }
                            completedIds.append(id)
                        },
                        initialState: [Int](),
                        count: 1
                    )
                    let queueStatus = repeater.send(.repeat(.value(15), semaphore))
                    guard case .enqueued = queueStatus else {
                        fatalError("Internal failure in Repeater reducer processing key, queueStatus: \(queueStatus)")
                    }
                }.forEach { key in fatalError("should not have key") }

                await withUnsafeContinuation { (completedContinuation: UnsafeContinuation<[Int], Never>) in
                    let semaphore = Semaphore.init(
                        continuation: completedContinuation,
                        reducer: { (completedIds: inout [Int], action: RepeatedAction<Int>) in
                            guard case let .repeated(id, .done) = action else { return }
                            completedIds.append(id)
                        },
                        initialState: [Int](),
                        count: 1
                    )

                    let queueStatus = repeater.send(.repeat(.completion(.finished), semaphore))
                    guard case .enqueued = queueStatus else {
                        fatalError("Internal failure in Repeater reducer processing key, queueStatus: \(queueStatus)")
                    }
                }.forEach { _ in () }
            }
        }
        do {
            try await FreeCombine.wait(for: expectation, timeout: 100_000_000)
        } catch {
            XCTFail("Timed out")
        }
    }
}
