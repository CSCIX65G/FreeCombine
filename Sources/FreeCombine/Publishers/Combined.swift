//
//  Combined.swift
//  
//
//  Created by Van Simmons on 6/4/22.
//

public extension Publisher {
    func combineLatest<Other>(
        _ other: Publisher<Other>
    ) -> Publisher<(Output?, Other?)> {
        Combined(self, other)
    }
}

public func Combined<Left, Right>(
    _ left: Publisher<Left>,
    _ right: Publisher<Right>
) -> Publisher<(Left?, Right?)> {
    combineLatest(left, right)
}

public func combineLatest<Left, Right>(
    _ left: Publisher<Left>,
    _ right: Publisher<Right>
) -> Publisher<(Left?, Right?)> {
    .init(
        initialState: CombineLatestState<Left, Right>.create(left: left, right: right),
        buffering: .bufferingOldest(2),
        reducer: Reducer(
            onCompletion: CombineLatestState<Left, Right>.complete,
            disposer: CombineLatestState<Left, Right>.dispose,
            reducer: CombineLatestState<Left, Right>.reduce
        ),
        extractor: \.mostRecentDemand
    )
}

public func combineLatest<A, B, C>(
    _ one: Publisher<A>,
    _ two: Publisher<B>,
    _ three: Publisher<C>
) -> Publisher<(A?, B?, C?)> {
    combineLatest(combineLatest(one, two), three)
        .map { ($0.0?.0, $0.0?.1, $0.1) }
}

public func combineLatest<A, B, C, D>(
    _ one: Publisher<A>,
    _ two: Publisher<B>,
    _ three: Publisher<C>,
    _ four: Publisher<D>
) -> Publisher<(A?, B?, C?, D?)> {
    combineLatest(combineLatest(one, two), combineLatest(three, four))
        .map { ($0.0?.0, $0.0?.1, $0.1?.0, $0.1?.1) }
}

public func combineLatest<A, B, C, D, E>(
    _ one: Publisher<A>,
    _ two: Publisher<B>,
    _ three: Publisher<C>,
    _ four: Publisher<D>,
    _ five: Publisher<E>
) -> Publisher<(A?, B?, C?, D?, E?)> {
    combineLatest(combineLatest(combineLatest(one, two), combineLatest(three, four)), five)
        .map { ($0.0?.0?.0, $0.0?.0?.1, $0.0?.1?.0, $0.0?.1?.1, $0.1) }
}

public func combineLatest<A, B, C, D, E, F>(
    _ one: Publisher<A>,
    _ two: Publisher<B>,
    _ three: Publisher<C>,
    _ four: Publisher<D>,
    _ five: Publisher<E>,
    _ six: Publisher<F>
) -> Publisher<(A?, B?, C?, D?, E?, F?)> {
    combineLatest(combineLatest(combineLatest(one, two), combineLatest(three, four)), combineLatest(five, six))
        .map { ($0.0?.0?.0, $0.0?.0?.1, $0.0?.1?.0, $0.0?.1?.1, $0.1?.0, $0.1?.1) }
}

public func combineLatest<A, B, C, D, E, F, G>(
    _ one: Publisher<A>,
    _ two: Publisher<B>,
    _ three: Publisher<C>,
    _ four: Publisher<D>,
    _ five: Publisher<E>,
    _ six: Publisher<F>,
    _ seven: Publisher<G>
) -> Publisher<(A?, B?, C?, D?, E?, F?, G?)> {
    combineLatest(combineLatest(combineLatest(one, two), combineLatest(three, four)), combineLatest(combineLatest(five, six), seven))
        .map { ($0.0?.0?.0, $0.0?.0?.1, $0.0?.1?.0, $0.0?.1?.1, $0.1?.0?.0, $0.1?.0?.1, $0.1?.1) }
}

public func combineLatest<A, B, C, D, E, F, G, H>(
    _ one: Publisher<A>,
    _ two: Publisher<B>,
    _ three: Publisher<C>,
    _ four: Publisher<D>,
    _ five: Publisher<E>,
    _ six: Publisher<F>,
    _ seven: Publisher<G>,
    _ eight: Publisher<H>
) -> Publisher<(A?, B?, C?, D?, E?, F?, G?, H?)> {
    combineLatest(combineLatest(combineLatest(one, two), combineLatest(three, four)), combineLatest(combineLatest(five, six), combineLatest(seven, eight)))
        .map { ($0.0?.0?.0, $0.0?.0?.1, $0.0?.1?.0, $0.0?.1?.1, $0.1?.0?.0, $0.1?.0?.1, $0.1?.1?.0, $0.1?.1?.1) }
}
