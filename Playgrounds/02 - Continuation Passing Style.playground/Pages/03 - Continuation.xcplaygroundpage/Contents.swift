//: [Previous](@previous)

public struct Continuation<A, R> {
    fileprivate let sink: (@escaping (A) -> R) -> R
    public init(_ sink: @escaping (@escaping (A) -> R) -> R) {
        self.sink = sink
    }
    public init(_ a: A) {
        self = .init { downstream in downstream(a) }
    }
    public func callAsFunction(_ f: @escaping (A) -> R) -> R {
        sink(f)
    }
}

public extension Continuation {
    func map<B>(_ f: @escaping (A) -> B) -> Continuation<B, R> {
        .init { downstream in self { a in
            downstream(f(a))
        } }
    }
    func flatMap<B>(_ f: @escaping (A) -> Continuation<B, R>) -> Continuation<B, R> {
        .init { downstream in self { a in
            f(a)(downstream)
        } }
    }
}

//: [Next](@next)
