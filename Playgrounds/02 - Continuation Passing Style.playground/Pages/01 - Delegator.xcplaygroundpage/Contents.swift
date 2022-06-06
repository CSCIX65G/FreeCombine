//: [Previous](@previous)

public struct Delegator<A> {
    public let sink: (@escaping (A) -> Void) -> Void

    internal init(_ sink: @escaping (@escaping (A) -> Void) -> Void) {
        self.sink = sink
    }
    public init(_ a: A) { self = .init { downstream in downstream(a) } }
    
    public func callAsFunction(_ f: @escaping (A) -> Void) -> Void {
        sink(f)
    }
}

public extension Delegator {
    func map<B>(_ f: @escaping (A) -> B) -> Delegator<B> {
        .init { downstream in self { a in
            downstream(f(a))
        } }
    }
    func flatMap<B>(_ f: @escaping (A) -> Delegator<B>) -> Delegator<B> {
        .init { downstream in self { a in
            f(a)(downstream)
        } }
    }
}

//: [Next](@next)
