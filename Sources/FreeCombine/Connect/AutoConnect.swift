//
//  Autoconnect.swift
//  
//
//  Created by Van Simmons on 6/7/22.
//
public extension Publisher {
    func autoconnect(
        buffering: AsyncStream<ConnectableState<Output>.Action>.Continuation.BufferingPolicy = .bufferingOldest(1)
    ) async -> Self {
        let connectable: Connectable<Output> = await self.makeConnectable(buffering: buffering)
        let cancellableRef: ValueRef<Cancellable<Demand>?> = .init(value: .none)
        return .init { continuation, downstream in
            Cancellable<Cancellable<Demand>>.join(.init {
                let cancellable = await connectable.publisher().sink(downstream)
                let refValue: Cancellable<Demand>! = await cancellableRef.value
                if refValue == nil {
                    do {
                        try await connectable.connect()
                        await cancellableRef.set(value: cancellable)
                        Task {
                            _ = await connectable.result;
                            _ = await cancellable.result;
                            await cancellableRef.set(value: .none)
                        }
                    } catch {
                        _ = try await connectable.cancelAndAwaitResult()
                    }
                }
                continuation.resume()
                return cancellable
            } )
        }
    }
}
