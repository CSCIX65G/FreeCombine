//
//  Wait.swift
//  
//
//  Created by Van Simmons on 2/20/22.
//

public func wait(
    for expectation: CheckedExpectation<Void>,
    timeout: UInt64
) async throws -> Void {
    try await wait(for: [expectation], timeout: timeout, reducing: (), with: {_, _ in })
}

public func wait<FinalResult, PartialResult>(
    for expectation: CheckedExpectation<PartialResult>,
    timeout: UInt64,
    reducing initialValue: FinalResult,
    with reducer: @escaping (inout FinalResult, PartialResult) throws -> Void
) async throws -> FinalResult {
    try await wait(for: [expectation], timeout: timeout, reducing: initialValue, with: reducer)
}

public func wait<FinalResult, PartialResult, S: Sequence>(
    for expectations: S,
    timeout: UInt64,
    reducing initialValue: FinalResult,
    with reducer: @escaping (inout FinalResult, PartialResult) throws -> Void
) async throws -> FinalResult where S.Element == CheckedExpectation<PartialResult> {
    let reducingTask = Task<FinalResult, Error>.init {
        let stateTask = await StateTask<WaitState<FinalResult, PartialResult>, WaitState<FinalResult, PartialResult>.Action>.stateTask(
            initialState: { channel in
                .init(with: channel, for: expectations, timeout: timeout, reducer: reducer, initialValue: initialValue)
            },
            buffering: .bufferingOldest(expectations.underestimatedCount + 1),
            reducer: WaitState<FinalResult, PartialResult>.reduce
        )
        return try await stateTask.finalState.finalResult
    }
    return try await reducingTask.value
}
