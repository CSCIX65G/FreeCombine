//: [Previous](@previous)

public struct Continuation<A, R> {
    fileprivate let sink: (@escaping (Result<A, Swift.Error>) -> R) -> R
    public init(_ sink: @escaping (@escaping (Result<A, Swift.Error>) -> R) -> R) {
        self.sink = sink
    }
    public init(_ a: Result<A, Swift.Error>) {
        self = .init { downstream in
            downstream(a)
        }
    }
    public func callAsFunction(_ f: @escaping (Result<A, Swift.Error>) -> R) -> R {
        sink(f)
    }
}

public extension Continuation {
    func map<B>(_ f: @escaping (A) -> B) -> Continuation<B, R> {
        .init { downstream in self { r in switch r {
            case .success(let a):
                return downstream(.success(f(a)))
            case .failure(let e):
                return downstream(.failure(e))
        } } }
    }
    func flatMap<B>(_ f: @escaping (A) -> Continuation<B, R>) -> Continuation<B, R> {
        .init { downstream in self { r in switch r {
            case .success(let a):
                return f(a)(downstream)
            case .failure(let e):
                return downstream(.failure(e))
        } } }
    }
}

//: [Next](@next)
