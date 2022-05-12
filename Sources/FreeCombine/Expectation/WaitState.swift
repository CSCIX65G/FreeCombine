//
//  File.swift
//  
//
//  Created by Van Simmons on 5/12/22.
//

struct WaitState<FinalResult, PartialResult> {
    typealias ST = StateTask<WaitState<FinalResult, PartialResult>, WaitState<FinalResult, PartialResult>.Action>
    enum Action {
        case complete(Int, PartialResult)
        case timeout
    }

    let channel: Channel<WaitState<FinalResult, PartialResult>.Action>
    let watchdog: Task<Void, Swift.Error>
    let stateReducer: (inout FinalResult, PartialResult) throws -> Void

    var expectations: [Int: CheckedExpectation<PartialResult>]
    var tasks: [Int: Task<PartialResult, Swift.Error>]
    var finalResult: FinalResult

    init<S: Sequence>(
        with channel: Channel<WaitState<FinalResult, PartialResult>.Action>,
        for expectations: S,
        timeout: UInt64,
        reducer: @escaping (inout FinalResult, PartialResult) throws -> Void,
        initialValue: FinalResult
    ) where S.Element == CheckedExpectation<PartialResult> {
        let tasks = expectations.enumerated().map { index, expectation in
            Task<PartialResult, Swift.Error> {
                guard !Task.isCancelled else { throw ST.Error.cancelled }
                let pResult = try await expectation.value()
                guard !Task.isCancelled else { throw ST.Error.cancelled }
                channel.yield(.complete(index, pResult))
                return pResult
            }
        }
        let expectationDict: [Int: CheckedExpectation<PartialResult>] = .init(
            uniqueKeysWithValues: expectations.enumerated().map { ($0, $1) }
        )
        let taskDict: [Int: Task<PartialResult, Swift.Error>] = .init(
            uniqueKeysWithValues: tasks.enumerated().map { ($0, $1) }
        )
        self.channel = channel
        self.expectations = expectationDict
        self.tasks = taskDict
        self.watchdog = .init {
            try await Task.sleep(nanoseconds: timeout)
            channel.yield(.timeout)
        }
        self.stateReducer = reducer
        self.finalResult = initialValue
    }

    mutating func cancel() -> Void {
        expectations.values.forEach { $0.cancel() }
        expectations.removeAll()
        tasks.removeAll()
    }
}
