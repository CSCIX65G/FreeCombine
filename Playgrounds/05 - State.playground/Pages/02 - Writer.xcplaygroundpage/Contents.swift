//: [Previous](@previous)

public struct Writer<Input, Output, W> {
    fileprivate let write: (Input) -> (Output, W)

    public init(_ write: @escaping (Input) -> (Output, W)) {
        self.write = write
    }

    public func callAsFunction(_ i: Input) -> (Output, W) {
        write(i)
    }

    func map<B>(
        _ f: @escaping (W) -> B
    ) -> Writer<Input, Output, B> {
        .init { i in let pair = self(i); return (pair.0, f(pair.1)) }
    }
    func flatMap<B>(
        _ f: @escaping (Input) -> Writer<Input, Output, B>
    ) -> Writer<Input, Output, B> {
        .init { i in f(i)(i) }
    }
}

//: [Next](@next)
