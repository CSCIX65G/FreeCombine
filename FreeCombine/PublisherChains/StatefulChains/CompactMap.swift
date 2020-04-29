//
//  CompactMap.swift
//  FreeCombine
//
//  Created by Van Simmons on 4/25/20.
//  Copyright © 2020 ComputeCycles, LLC. All rights reserved.
//

public extension Publisher {
    func compactMap<T>(
        _ isIncluded: @escaping (T?) -> T
    ) -> Publisher<Output, Failure> where Output == T? {
        return transformation(
            joinSubscriber: Subscriber<Output, Failure>.join({ $0 != nil }),
            transformPublication: identity
        )
    }
}
