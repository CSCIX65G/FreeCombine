//
//  Publisher+Inits.swift
//  FreeCombine
//
//  Created by Van Simmons on 4/12/20.
//  Copyright © 2020 ComputeCycles, LLC. All rights reserved.
//

extension Publisher: CallableAsFunction {
    public init(_ call: @escaping (Subscriber<Output, Failure>) -> Subscription) {
        self.call = call
    }

    public init(_ f: Func<Subscriber<Output, Failure>, Subscription>) {
        self.call = f.call
    }
}

extension Publisher {
    func receive(subscriber: Subscriber<Output, Failure>) -> Subscription {
        self(subscriber)
    }
}

public extension Publisher {
    init(_ producer: Producer<Output, Failure>) {
        self.call = { subscriber in
            .init(Func(subscriber |> producer.bind).map {_ in })
        }
    }
}

public extension Publisher {
    // Empty
    static func Empty<T>(_ t: T.Type) -> Publisher<T, Never> {
        .init(Producer.empty())
    }
    
    // Just
    static func Just<T>(_ value: T) -> Publisher<T, Never> {
        .init(Producer.just(value))
    }
    
    // PublishedSequence
    static func PublishedSequence<S: Sequence>(_ values: S) -> Publisher<S.Element, Never> {
        .init(Producer.sequence(values))
    }
}

