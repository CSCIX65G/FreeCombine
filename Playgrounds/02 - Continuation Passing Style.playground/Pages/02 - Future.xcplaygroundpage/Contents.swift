//: [Previous](@previous)

public struct Future<A, E: Error> {
    public let sink: (@escaping (Result<A, E>) -> Void) -> Void
    init(_ sink: @escaping (@escaping (Result<A, E>) -> Void) -> Void) {
        self.sink = sink
    }
}

public extension Future {
    init(_ a: A) {
        self = Future<A, E> { callback in callback(.success(a)) }
    }
    init(_ error: E) {
        self = Future<A, E> { callback in callback(.failure(error)) }
    }
    func callAsFunction(_ f: @escaping (Result<A, E>) -> Void) -> Void {
        sink(f)
    }
}

public extension Future {
    func map<B>(_ f: @escaping (A) -> B) -> Future<B, E> {
        .init { downstream in self { r in switch r {
            case .success(let a):
                downstream(.success(f(a)))
            case .failure(let e):
                downstream(.failure(e))
        } } }
    }
    func flatMap<B>(_ f: @escaping (A) -> Future<B, E>) -> Future<B, E> {
        .init { downstream in self { r in switch r {
            case .success(let a):
                f(a)(downstream)
            case .failure(let e):
                downstream(.failure(e))
        } } }
    }
}

//: [Next](@next)
