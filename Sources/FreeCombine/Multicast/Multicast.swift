//
//  Multicast.swift
//  
//
//  Created by Van Simmons on 6/26/22.
//
public extension Publisher {
    func multicast(_ subject: Subject<Output>) -> Self {
        .init { resumption, downstream in
            self.sink(onStartup: resumption, { result in
                switch result {
                    case .completion(.failure(let error)):
                        try await subject.fail(error)
                    case .completion(.cancelled):
                        try await subject.cancel()
                    case .completion(.finished):
                        try await subject.finish()
                    case .value(let value):
                        try await subject.blockingSend(value)
                }
                return try await downstream(result)
            })
        }
    }

    func multicast(
        _ generator: @escaping () -> StateTask<DistributorState<Output>, DistributorState<Output>.Action>
    ) async -> Self {
        let subject = generator()
        return .init { resumption, downstream in
            self.sink(onStartup: resumption, { result in
                switch result {
                    case .completion(.failure(let error)):
                        try await subject.fail(error)
                    case .completion(.cancelled):
                        try await subject.cancel()
                    case .completion(.finished):
                        try await subject.finish()
                    case .value(let value):
                        try await subject.send(value)
                }
                return try await downstream(result)
            })
        }
    }
}
