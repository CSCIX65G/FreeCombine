//: [Previous](@previous)

public struct AsyncContinuation<A, R> {
    fileprivate let sink: (@escaping (Result<A, Swift.Error>) async -> R) async -> R
    public init(_ sink: @escaping (@escaping (Result<A, Swift.Error>) async -> R) async-> R) {
        self.sink = sink
    }
    public init(_ a: Result<A, Swift.Error>) {
        self = .init { downstream in await downstream(a) }
    }
    public func callAsFunction(_ f: @escaping (Result<A, Swift.Error>) async -> R) async -> R {
        await sink(f)
    }
}

public extension AsyncContinuation {
    func map<B>(_ f: @escaping (A) async -> B) async -> AsyncContinuation<B, R> {
        .init { downstream in await self { r in switch r {
            case .success(let a):
                return await downstream(.success(f(a)))
            case .failure(let e):
                return await downstream(.failure(e))
        } } }
    }
    func flatMap<B>(_ f: @escaping (A) async -> AsyncContinuation<B, R>) async -> AsyncContinuation<B, R> {
        .init { downstream in await self { r in switch r {
            case .success(let a):
                return await f(a)(downstream)
            case .failure(let e):
                return await downstream(.failure(e))
        } } }
    }
}

//: [Next](@next)
