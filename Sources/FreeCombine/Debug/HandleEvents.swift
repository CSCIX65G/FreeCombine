//
//  HandleEvents.swift
//  
//
//  Created by Van Simmons on 6/6/22.
//
public extension Publisher {
    func handleEvents(
        receiveSubscriber: @escaping (@escaping (AsyncStream<Output>.Result) async throws -> Demand) -> Void = {_ in },
        receiveOutput: @escaping (Output) -> Void = { _ in },
        receiveFinished: @escaping () -> Void = { },
        receiveFailure: @escaping (Swift.Error) -> Void = {_ in },
        receiveCancel: @escaping () -> Void = { },
        receiveDemand: @escaping (Demand) -> Void = { _ in }
    ) -> Self {
        .init { continuation, downstream in
            receiveSubscriber(downstream)
            return self(onStartup: continuation) { r in
                switch r {
                    case .value(let a):
                        receiveOutput(a)
                    case .completion(.finished):
                        receiveFinished()
                    case .completion(.cancelled):
                        receiveCancel()
                    case let .completion(.failure(error)):
                        receiveFailure(error)
                }
                let demand = try await downstream(r)
                receiveDemand(demand)
                return demand
            }
        }
    }
}
