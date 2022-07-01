//
//  Distributor.swift
//  
//
//  Created by Van Simmons on 6/28/22.
//
public final class Distributor<Output: Sendable> {
    private let stateTask: StateTask<DistributorState<Output>, DistributorState<Output>.Action>
    init(stateTask: StateTask<DistributorState<Output>, DistributorState<Output>.Action>) {
        self.stateTask = stateTask
    }
    init(stateTask: @escaping () async throws -> StateTask<DistributorState<Output>, DistributorState<Output>.Action>) async throws {
        self.stateTask = try await stateTask()
    }
    public var value: DistributorState<Output> {
        get async throws { try await stateTask.value }
    }
    public var result: Result<DistributorState<Output>, Swift.Error> {
        get async { await stateTask.result }
    }
    public func cancelAndAwaitResult() async throws -> Result<DistributorState<Output>, Swift.Error> {
        try await stateTask.cancel()
        return await stateTask.result
    }
    public func finish() async throws -> Void {
        try await stateTask.finish()
        _ = await stateTask.result
    }
}

public extension Distributor {
    func publisher(
        file: StaticString = #file,
        line: UInt = #line,
        deinitBehavior: DeinitBehavior = .assert
    ) -> Publisher<Output> {
        .init(file: file, line: line, deinitBehavior: deinitBehavior, stateTask: stateTask)
    }

    func subscribe(
        _ downstream: @Sendable @escaping (AsyncStream<Output>.Result) async throws -> Demand
    ) async throws -> Cancellable<Demand> {
        try await withResumption { resumption in
            let queueStatus = stateTask.send(.subscribe(downstream, resumption))
            switch queueStatus {
                case .enqueued:
                    ()
                case .terminated:
                    resumption.resume(throwing: PublisherError.completed)
                case .dropped:
                    resumption.resume(throwing: PublisherError.enqueueError)
                @unknown default:
                    resumption.resume(throwing: PublisherError.enqueueError)
            }
        }
    }

//    func receive(
//        _ result: AsyncStream<Output>.Result
//    ) async throws -> Void {
//        try await withResumption { resumption in
//            let queueStatus = stateTask.send(.receive(result, resumption))
//            switch queueStatus {
//                case .enqueued:
//                    ()
//                case .terminated:
//                    resumption.resume(throwing: PublisherError.completed)
//                case .dropped:
//                    resumption.resume(throwing: PublisherError.enqueueError)
//                @unknown default:
//                    resumption.resume(throwing: PublisherError.enqueueError)
//            }
//        }
//    }
}
