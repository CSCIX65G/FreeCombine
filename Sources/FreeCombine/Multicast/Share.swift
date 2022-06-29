//
//  Share.swift
//  
//
//  Created by Van Simmons on 6/26/22.
//
public extension Publisher {
    func share(
        buffering: AsyncStream<DistributorState<Output>.Action>.Continuation.BufferingPolicy = .bufferingOldest(1)
    ) async -> Self {
        let subject: StateTask<DistributorState<Output>, DistributorState<Output>.Action> = await PassthroughSubject(
            buffering: buffering
        )
        let cancellableRef: ValueRef<Cancellable<Demand>?> = .init(value: .none)
        return .init { continuation, downstream in
            return Cancellable<Cancellable<Demand>>.join(.init {
                    let cancellable = await subject.publisher().sink(downstream)
                    var i1: Cancellable<Demand>! = await cancellableRef.value
                    let isNew = i1 == nil
                    if i1 == nil {
                        i1 = await self.sink({ result in
                            do {
                                switch result {
                                    case .value(let value):
                                        try await subject.send(.value(value))
                                        return .more
                                    case .completion(.finished):
                                        try await subject.send(.completion(.finished))
                                        return .done
                                    case .completion(.cancelled):
                                        try await subject.send(.completion(.cancelled))
                                        return .done
                                    case .completion(.failure(let error)):
                                        try await subject.send(.completion(.failure(error)))
                                        throw error
                                }
                            } catch {
                                Swift.print(error)
                                throw error
                            }
                        })
                        let i2: Cancellable<Demand> = i1
                        Task {
                            _ = await subject.result;
                            _ = await i2.result;
                            await cancellableRef.set(value: .none)
                        }
                        await cancellableRef.set(value: i1)
                    }
                    if (i1.isCompleting || i1.isCancelled) && isNew {
                        Swift.print("cancelled early, isNew = \(isNew)")
                    }
                    continuation.resume()
                    return cancellable
                } )
        }
    }
}

