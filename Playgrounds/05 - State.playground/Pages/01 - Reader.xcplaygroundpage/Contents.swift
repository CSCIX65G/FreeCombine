//: [Previous](@previous)

public struct Reader<E, A> {
    fileprivate let read: (E) -> A

    public init(_ read: @escaping (E) -> A) {
        self.read = read
    }

    public func callAsFunction(_ e: E) -> A {
        read(e)
    }

    func map<B>(_ f: @escaping (A) -> B) -> Reader<E, B> {
        .init { a in f(self(a)) }
    }
    func flatMap<B>(_ f: @escaping (A) -> Reader<E, B>) -> Reader<E, B> {
        .init { e in f(self(e))(e) }
    }
}

//: [Next](@next)
