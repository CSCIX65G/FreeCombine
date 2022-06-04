//
//  Zipped.swift
//  
//
//  Created by Van Simmons on 5/8/22.
//

public extension Publisher {
    func zip<Other>(
        onCancel: @escaping () -> Void = { },
        _ other: Publisher<Other>
    ) -> Publisher<(Output, Other)> {
        Zipped(onCancel: onCancel, self, other)
    }
}

public func Zipped<Left, Right>(
    onCancel: @escaping () -> Void = { },
    _ left: Publisher<Left>,
    _ right: Publisher<Right>
) -> Publisher<(Left, Right)> {
    zip(onCancel: onCancel, left, right)
}

public func zip<Left, Right>(
    onCancel: @escaping () -> Void = { },
    _ left: Publisher<Left>,
    _ right: Publisher<Right>
) -> Publisher<(Left, Right)> {
    .init(
        initialState: ZipState<Left, Right>.create(left: left, right: right),
        buffering: .bufferingOldest(2),
        onCancel: onCancel,
        reducer: Reducer(
            onCompletion: ZipState<Left, Right>.complete,
            reducer: ZipState<Left, Right>.reduce
        )
    )
}

public func zip<A, B, C>(
    onCancel: @escaping () -> Void = { },
    _ one: Publisher<A>,
    _ two: Publisher<B>,
    _ three: Publisher<C>
) -> Publisher<(A, B, C)> {
    zip(onCancel: onCancel, zip(one, two), three)
        .map { ($0.0.0, $0.0.1, $0.1) }
}

public func zip<A, B, C, D>(
    onCancel: @escaping () -> Void = { },
    _ one: Publisher<A>,
    _ two: Publisher<B>,
    _ three: Publisher<C>,
    _ four: Publisher<D>
) -> Publisher<(A, B, C, D)> {
    zip(onCancel: onCancel, zip(one, two), zip(three, four))
        .map { ($0.0.0, $0.0.1, $0.1.0, $0.1.1) }
}

public func zip<A, B, C, D, E>(
    onCancel: @escaping () -> Void = { },
    _ one: Publisher<A>,
    _ two: Publisher<B>,
    _ three: Publisher<C>,
    _ four: Publisher<D>,
    _ five: Publisher<E>
) -> Publisher<(A, B, C, D, E)> {
    zip(onCancel: onCancel, zip(zip(one, two), zip(three, four)), five)
        .map { ($0.0.0.0, $0.0.0.1, $0.0.1.0, $0.0.1.1, $0.1) }
}

public func zip<A, B, C, D, E, F>(
    onCancel: @escaping () -> Void = { },
    _ one: Publisher<A>,
    _ two: Publisher<B>,
    _ three: Publisher<C>,
    _ four: Publisher<D>,
    _ five: Publisher<E>,
    _ six: Publisher<F>
) -> Publisher<(A, B, C, D, E, F)> {
    zip(onCancel: onCancel, zip(zip(one, two), zip(three, four)), zip(five, six))
        .map { ($0.0.0.0, $0.0.0.1, $0.0.1.0, $0.0.1.1, $0.1.0, $0.1.1) }
}

public func zip<A, B, C, D, E, F, G>(
    onCancel: @escaping () -> Void = { },
    _ one: Publisher<A>,
    _ two: Publisher<B>,
    _ three: Publisher<C>,
    _ four: Publisher<D>,
    _ five: Publisher<E>,
    _ six: Publisher<F>,
    _ seven: Publisher<G>
) -> Publisher<(A, B, C, D, E, F, G)> {
    zip(onCancel: onCancel, zip(zip(one, two), zip(three, four)), zip(zip(five, six), seven))
        .map { ($0.0.0.0, $0.0.0.1, $0.0.1.0, $0.0.1.1, $0.1.0.0, $0.1.0.1, $0.1.1) }
}

public func zip<A, B, C, D, E, F, G, H>(
    onCancel: @escaping () -> Void = { },
    _ one: Publisher<A>,
    _ two: Publisher<B>,
    _ three: Publisher<C>,
    _ four: Publisher<D>,
    _ five: Publisher<E>,
    _ six: Publisher<F>,
    _ seven: Publisher<G>,
    _ eight: Publisher<H>
) -> Publisher<(A, B, C, D, E, F, G, H)> {
    zip(onCancel: onCancel, zip(zip(one, two), zip(three, four)), zip(zip(five, six), zip(seven, eight)))
        .map { ($0.0.0.0, $0.0.0.1, $0.0.1.0, $0.0.1.1, $0.1.0.0, $0.1.0.1, $0.1.1.0, $0.1.1.1) }
}
