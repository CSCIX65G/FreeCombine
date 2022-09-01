//
//  Fold.swift
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
//public extension Future {
//    func fold(
//        with upstream2: Future<Output>,
//        _ otherUpstreams: Future<Output>...
//    ) -> Future<Output> {
//        Folded(self, upstream2, otherUpstreams)
//    }
//}
//
//public func Folded<Output, S: Sequence>(
//    _ upstream1: Future<Output>,
//    _ upstream2: Future<Output>,
//    _ otherUpstreams: S
//) -> Future<Output> where S.Element == Future<Output> {
//    fold(futures: upstream1, upstream2, otherUpstreams)
//}
//
//public func Folded<Output>(
//    _ upstream1: Future<Output>,
//    _ upstream2: Future<Output>,
//    _ otherUpstreams: Future<Output>...
//) -> Future<Output> {
//    fold(futures: upstream1, upstream2, otherUpstreams)
//}
//
//public func fold<Output>(
//    futures upstream1: Future<Output>,
//    _ upstream2: Future<Output>,
//    _ otherUpstreams: Future<Output>...
//) -> Future<Output> {
//    fold(futures: upstream1, upstream2, otherUpstreams)
//}
//
//public func fold<Output, S: Sequence>(
//    futures upstream1: Future<Output>,
//    _ upstream2: Future<Output>,
//    _ otherUpstreams: S
//) -> Future<Output> where S.Element == Future<Output> {
//    .init(
//        initialState: MergeState<Output>.create(upstreams: upstream1, upstream2, otherUpstreams),
//        buffering: .bufferingOldest(2 + otherUpstreams.underestimatedCount),
//        reducer: Reducer(
//            reducer: MergeState<Output>.reduce,
//            disposer: MergeState<Output>.dispose,
//            finalizer: MergeState<Output>.complete
//        ),
//        extractor: \.mostRecentDemand
//    )
//}
//
//public func fold<Output, S: Sequence>(
//    futures: S
//) -> Future<Output> where S.Element == Future<Output> {
//    let array = Array(futures)
//    switch array.count {
//        case 1:
//            return array[0]
//        case 2:
//            return Folded(array[0], array[1])
//        case 3... :
//            return Folded(array[0], array[1], array[2...])
//        default:
//            return Future<Output>.init(error: FutureError.internalError)
//    }
//}
