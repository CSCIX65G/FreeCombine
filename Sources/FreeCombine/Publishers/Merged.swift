//
//  Merged.swift
//  
//
//  Created by Van Simmons on 5/19/22.
//

public extension Publisher {
    func merge(
        with upstream2: Publisher<Output>,
        _ otherUpstreams: Publisher<Output>...
    ) -> Publisher<Output> {
        Merged(self, upstream2, otherUpstreams)
    }
}

public func Merged<Output>(
    _ upstream1: Publisher<Output>,
    _ upstream2: Publisher<Output>,
    _ otherUpstreams: [Publisher<Output>]
) -> Publisher<Output> {
    merge(publishers: upstream1, upstream2, otherUpstreams)
}

public func Merged<Output>(
    _ upstream1: Publisher<Output>,
    _ upstream2: Publisher<Output>,
    _ otherUpstreams: Publisher<Output>...
) -> Publisher<Output> {
    merge(publishers: upstream1, upstream2, otherUpstreams)
}

public func merge<Output>(
    publishers upstream1: Publisher<Output>,
    _ upstream2: Publisher<Output>,
    _ otherUpstreams: Publisher<Output>...
) -> Publisher<Output> {
    merge(publishers: upstream1, upstream2, otherUpstreams)
}

public func merge<Output>(
    publishers upstream1: Publisher<Output>,
    _ upstream2: Publisher<Output>,
    _ otherUpstreams: [Publisher<Output>]
) -> Publisher<Output> {
    .init(
        initialState: MergeState<Output>.create(upstreams: upstream1, upstream2, otherUpstreams),
        buffering: .bufferingOldest(2 + otherUpstreams.count),
        reducer: Reducer(
            onCompletion: MergeState<Output>.complete,
            disposer: MergeState<Output>.dispose,
            reducer: MergeState<Output>.reduce
        ),
        extractor: \.mostRecentDemand
    )
}
