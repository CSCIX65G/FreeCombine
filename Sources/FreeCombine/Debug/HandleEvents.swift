//
//  HandleEvents.swift
//  
//
//  Created by Van Simmons on 6/6/22.
//
public extension Publisher {
    func handleEvents(
        receiveDownstream: @escaping (@escaping (AsyncStream<Output>.Result) async throws -> Demand) -> Void = {_ in },
        receiveResult: @escaping (AsyncStream<Output>.Result) async -> Void = { _ in },
        receiveDemand: @escaping (Demand) async -> Void = { _ in }
    ) -> Self {
        .init { continuation, downstream in
            receiveDownstream(downstream)
            return self(onStartup: continuation) { r in
                await receiveResult(r)
                let demand = try await downstream(r)
                await receiveDemand(demand)
                return demand
            }
        }
    }

    func handleEvents(
        receiveDownstream: @escaping (@escaping (AsyncStream<Output>.Result) async throws -> Demand) -> Void = {_ in },
        receiveOutput: @escaping (Output) async -> Void = { _ in },
        receiveFinished: @escaping () async -> Void = { },
        receiveFailure: @escaping (Swift.Error) async -> Void = {_ in },
        receiveCancel: @escaping () async -> Void = { },
        receiveDemand: @escaping (Demand) async -> Void = { _ in }
    ) -> Self {
        .init { continuation, downstream in
            receiveDownstream(downstream)
            return self(onStartup: continuation) { r in
                switch r {
                    case .value(let a):
                        await receiveOutput(a)
                    case .completion(.finished):
                        await receiveFinished()
                    case .completion(.cancelled):
                        await receiveCancel()
                    case let .completion(.failure(error)):
                        await receiveFailure(error)
                }
                let demand = try await downstream(r)
                await receiveDemand(demand)
                return demand
            }
        }
    }
}
