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
    with reducer: @escaping (FinalResult, PartialResult) throws -> FinalResult
) async throws -> FinalResult {
    try await wait(for: [expectation], timeout: timeout, reducing: initialValue, with: reducer)
}

public func wait<FinalResult, PartialResult, S: Sequence>(
    for expecations: S,
    timeout: UInt64,
    reducing initialValue: FinalResult,
    with reducer: @escaping (FinalResult, PartialResult) throws -> FinalResult
) async throws -> FinalResult where S.Element == CheckedExpectation<PartialResult> {
    let reducingTask = Task<FinalResult, Error>.init {
        let cancellationGroup = CancellationGroup()
        let reducingTask: Task<FinalResult, Error> = .init {
            try await withTaskCancellationHandler(handler: { expecations.forEach {
                guard !$0.isCancelled else { return }
                $0.cancel()
            } } ) {
                var currentValue = initialValue
                do {
                    for expectation in expecations {
                        guard !Task.isCancelled else { throw CheckedExpectation<FinalResult>.Error.cancelled }
                        currentValue = try reducer(currentValue, try await expectation.value())
                    }
                } catch {
                    await Task.yield()
                    withUnsafeCurrentTask { currentTask in
                        if let currentTask = currentTask, !currentTask.isCancelled {
                            currentTask.cancel()
                        }
                    }
                    await Task.yield()
                    throw error
                }
                await Task.yield()
                try await cancellationGroup.cancel()
                return currentValue
            }
        }
        
        let timeout: Task<Void, Never> = .init {
            do {
                await Task.yield()
                try await Task.sleep(nanoseconds: timeout)
                await Task.yield()
                reducingTask.cancel()
            } catch {
                return
            }
        }
        guard !Task.isCancelled else {
            throw CheckedExpectation<FinalResult>.Error.alreadyCancelled
        }
        await cancellationGroup.add(timeout)
        do {
            return try await reducingTask.value
        } catch {
            throw error
        }
    }
    return try await reducingTask.value
}
