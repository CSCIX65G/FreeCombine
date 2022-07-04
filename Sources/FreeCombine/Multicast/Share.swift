//
//  Share.swift
//  
//
//  Created by Van Simmons on 6/26/22.
//
public extension Publisher {
    func share(
        buffering: AsyncStream<DistributorState<Output>.Action>.Continuation.BufferingPolicy = .bufferingOldest(1)
    ) async throws -> Self {
        let subject: Subject<Output> = try await PassthroughSubject()
        let cancellableRef: ValueRef<Cancellable<Demand>?> = .init(value: .none)
        return .init { continuation, downstream in
            Cancellable<Cancellable<Demand>>.join(.init {
                let cancellable = await subject.publisher().sink(downstream)
                var i1: Cancellable<Demand>! = await cancellableRef.value
                if i1 == nil {
                    i1 = await self.sink({ result in
                        do {
                            switch result {
                                case .value(let value):
                                    try await subject.send(value)
                                    return .more
                                case .completion(.finished):
                                    try await subject.finish()
                                    _ = await subject.result
                                    return .done
                                case .completion(.cancelled):
                                    try await subject.cancel()
                                    _ = await subject.result
                                    return .done
                                case .completion(.failure(let error)):
                                    try await subject.fail(error)
                                    _ = await subject.result
                                    throw error
                            }
                        } catch {
                            _ = await cancellable.cancelAndAwaitResult()
                            _ = await subject.result;
                            throw error
                        }
                    })
                    let i2: Cancellable<Demand> = i1
                    Task {
                        _ = await cancellable.result
                        _ = await subject.result;
                        _ = await i2.result;
                        await cancellableRef.set(value: .none)
                    }
                    await cancellableRef.set(value: i1)
                }
                continuation.resume()
                return cancellable
            } )
        }
    }
}

