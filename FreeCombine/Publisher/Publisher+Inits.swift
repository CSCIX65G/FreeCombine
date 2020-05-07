//
//  Publisher+Inits.swift
//  FreeCombine
//
//  Created by Van Simmons on 4/12/20.
//  Copyright © 2020 ComputeCycles, LLC. All rights reserved.
//

public func Empty<T>(_ t: T.Type) -> Publisher<T, Never> {
    .init(Producer.empty())
}

public func Just<T>(_ value: T) -> Publisher<T, Never> {
    .init(Producer.just(value))
}

public func PublishedSequence<S: Sequence>(_ values: S) -> Publisher<S.Element, Never> {
    values.publisher
}

public extension Sequence {
    // PublishedSequence
    var publisher: Publisher<Self.Element, Never> {
        Publisher<Self.Element, Never>.init(Producer.sequence(self))
    }
}

