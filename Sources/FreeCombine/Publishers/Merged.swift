//
//  Merged.swift
//  
//
//  Created by Van Simmons on 5/19/22.
//

public extension Publisher {
    func merge(
        onCancel: @escaping () -> Void = { },
        others upstream2: Publisher<Output>,
        _ otherUpstreams: Publisher<Output>...
    ) -> Publisher<Output> {
        Merged(onCancel: onCancel, publishers: self, upstream2, otherUpstreams)
    }
}

public func Merged<Output>(
    onCancel: @escaping () -> Void = { },
    publishers upstream1: Publisher<Output>,
    _ upstream2: Publisher<Output>,
    _ otherUpstreams: [Publisher<Output>]
) -> Publisher<Output> {
    merge(onCancel: onCancel, publishers: upstream1, upstream2, otherUpstreams)
}

public func Merged<Output>(
    onCancel: @escaping () -> Void = { },
    publishers upstream1: Publisher<Output>,
    _ upstream2: Publisher<Output>,
    _ otherUpstreams: Publisher<Output>...
) -> Publisher<Output> {
    merge(onCancel: onCancel, publishers: upstream1, upstream2, otherUpstreams)
}

public func merge<Output>(
    onCancel: @escaping () -> Void = { },
    publishers upstream1: Publisher<Output>,
    _ upstream2: Publisher<Output>,
    _ otherUpstreams: Publisher<Output>...
) -> Publisher<Output> {
    merge(onCancel: onCancel, publishers: upstream1, upstream2, otherUpstreams)
}

public func merge<Output>(
    onCancel: @escaping () -> Void = { },
    publishers upstream1: Publisher<Output>,
    _ upstream2: Publisher<Output>,
    _ otherUpstreams: [Publisher<Output>]
) -> Publisher<Output> {
    .init(
        initialState: MergeState<Output>.create(upstreams: upstream1, upstream2, otherUpstreams),
        buffering: .bufferingOldest(2 + otherUpstreams.count),
        onCancel: onCancel,
        onCompletion: MergeState<Output>.complete,
        reducer: Reducer(
            disposer: { action, error in
                if case let .setValue(_, continuation) = action {
                    continuation.resume(returning: .done)
                }
            },
            reducer: MergeState<Output>.reduce
        )
    )
}

