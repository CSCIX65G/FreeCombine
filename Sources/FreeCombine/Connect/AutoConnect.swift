//
//  Autoconnect.swift
//  
//
//  Created by Van Simmons on 6/7/22.
//
public extension Publisher {
    func autoconnect(
        file: StaticString = #file,
        line: UInt = #line,
        deinitBehavior: DeinitBehavior = .assert,
        buffering: AsyncStream<ConnectableRepeaterState<Output>.Action>.Continuation.BufferingPolicy = .bufferingOldest(1)
    ) async throws -> Self {
        let connectable: Connectable<Output> = try await self.makeConnectable(buffering: buffering)
        let cancellableRef: ValueRef<Cancellable<Demand>?> = .init(value: .none)
        return .init { continuation, downstream in
            Cancellable<Cancellable<Demand>>.join(.init {
                let cancellable = await connectable.publisher().sink(downstream)
                let refValue: Cancellable<Demand>! = await cancellableRef.value
                if refValue == nil {
                    do {
                        Task {
                            _ = await connectable.result
                            _ = await cancellable.result
                            try await cancellableRef.set(value: .none)
                        }
                        try await connectable.connect()
                        try await cancellableRef.set(value: cancellable)
                    } catch {
//                        _ = try? await downstream(.completion(.finished))
                        continuation.resume()
                        _ = try await connectable.cancelAndAwaitResult()
                    }
                }
                continuation.resume()
                return cancellable
            } )
        }
    }
}
