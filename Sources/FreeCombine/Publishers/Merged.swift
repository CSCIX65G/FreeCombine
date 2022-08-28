//
//  Merged.swift
//  
//
//  Created by Van Simmons on 5/19/22.
//
//  Copyright 2022, ComputeCycles, LLC
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//
public extension Publisher {
    func merge(
        with upstream2: Publisher<Output>,
        _ otherUpstreams: Publisher<Output>...
    ) -> Publisher<Output> {
        Merged(self, upstream2, otherUpstreams)
    }
}

public func Merged<Output, S: Sequence>(
    _ upstream1: Publisher<Output>,
    _ upstream2: Publisher<Output>,
    _ otherUpstreams: S
) -> Publisher<Output> where S.Element == Publisher<Output> {
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

public func merge<Output, S: Sequence>(
    publishers upstream1: Publisher<Output>,
    _ upstream2: Publisher<Output>,
    _ otherUpstreams: S
) -> Publisher<Output> where S.Element == Publisher<Output> {
    .init(
        initialState: MergeState<Output>.create(upstreams: upstream1, upstream2, otherUpstreams),
        buffering: .bufferingOldest(2 + otherUpstreams.underestimatedCount),
        reducer: Reducer(
            reducer: MergeState<Output>.reduce,
            disposer: MergeState<Output>.dispose,
            finalizer: MergeState<Output>.complete
        ),
        extractor: \.mostRecentDemand
    )
}

public func merge<Output, S: Sequence>(
    publishers: S
) -> Publisher<Output> where S.Element == Publisher<Output> {
    let array = Array(publishers)
    switch array.count {
        case 1:
            return array[0]
        case 2:
            return Merged(array[0], array[1])
        case 3... :
            return Merged(array[0], array[1], array[2...])
        default:
            return Publisher<Output>.init()
    }
}
