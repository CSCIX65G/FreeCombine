//: [Previous](@previous)
import _Concurrency

public struct AsyncTaskContinuation<A, R> {
    fileprivate let sink: (@escaping (Result<A, Swift.Error>) async throws -> R) -> Task<R, Swift.Error>

    public init(
        _ sink: @escaping (@escaping (Result<A, Swift.Error>) async throws -> R
    ) -> Task<R, Swift.Error>) {
        self.sink = sink
    }
    public init(_ a: Result<A, Swift.Error>) {
        self = .init { downstream in Task { try await downstream(a) } }
    }
    public func callAsFunction(
        _ f: @escaping (Result<A, Swift.Error>) async throws -> R
    ) -> Task<R, Swift.Error> {
        sink(f)
    }
}

public extension AsyncTaskContinuation {
    func map<B>(
        _ f: @escaping (A) async -> B
    ) async -> AsyncTaskContinuation<B, R> {
        .init { downstream in self { r in switch r {
            case .success(let a):
                return try await downstream(.success(f(a)))
            case .failure(let e):
                return try await downstream(.failure(e))
        } } }
    }
    func flatMap<B>(
        _ f: @escaping (A) async -> AsyncTaskContinuation<B, R>
    ) async -> AsyncTaskContinuation<B, R> {
        .init { downstream in self { r in switch r {
            case .success(let a):
                return try await f(a)(downstream).value
            case .failure(let e):
                return try await downstream(.failure(e))
        } } }
    }
}

//: [Next](@next)
