//
//  Subject.swift
//  
//
//  Created by Van Simmons on 3/22/22.
//

fileprivate struct SubjectState<Output> {
    
}

public class Subject<Output> {
//    let distributor: AsyncReducer<SubjectState<Output>, SubjectAction<Output>>
//
//    public init(
//        for: Output.Type = Output.self,
//        buffering: AsyncStream<AsyncStream<Output>.Result>.Continuation.BufferingPolicy = .unbounded,
//        onTermination: (@Sendable (AsyncStream<AsyncStream<Output>.Result>.Continuation.Termination) -> Void)? = .none,
//        onCancel: Cancellable = .empty,
//        reducer: ((AsyncStream<Output>.Result?, AsyncStream<Output>.Result) -> AsyncStream<Output>.Result?)? = .none
//    ) {
//        self.group = .init(
//            buffering: buffering,
//            onTermination: onTermination,
//            onCancel: onCancel,
//            reducer: reducer
//        )
//    }
//
//    nonisolated public func send(_ value: Output) throws -> Void {
//        try group.enqueue(.value(value))
//    }
//
//    nonisolated public func send(completion: Publisher<Output>.Completion) throws -> Void {
//        switch completion {
//            case .finished: group.finish()
//            case let .failure(error): try group.enqueue(.failure(error))
//        }
//    }
//
//    nonisolated public func finish() -> Void {
//        group.yield(.terminated)
//        group.finish()
//    }
//
//    enum Error: Swift.Error {
//        case done
//    }
//
//    public func publisher(
//        onCancel: Cancellable = .empty ,
//        onTermination: (@Sendable (AsyncStream<AsyncStream<Output>.Result>.Continuation.Termination) -> Void)? = .none,
//        onExit: (@Sendable (AsyncStream<Output>.Result, Demand) -> Void)? = .none
//    ) -> Publisher<Output> {
//        .init { (downstream: @escaping (AsyncStream<Output>.Result) async -> Demand) async -> Task<Demand, Swift.Error>  in
//            await self.group.add(
//                onCancellation: onCancel,
//                onTermination: onTermination,
//                onExit: onExit,
//                operation: { value in
//                    if await downstream(value) == .done {
//                        return .done
//                    }
//                    return .more
//                },
//                shouldExit: { $1 == .done }
//            )
//        }
//    }
}
