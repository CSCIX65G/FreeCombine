//
//  Share.swift
//  
//
//  Created by Van Simmons on 6/26/22.
//
public extension Publisher {
    func share(
        buffering: AsyncStream<ConnectableState<Output>.Action>.Continuation.BufferingPolicy = .bufferingOldest(1)
    ) async -> Self {
        var subject: StateTask<DistributorState<Output>, DistributorState<Output>.Action>!
        let _: Void = try! await withResumption { resumption in
            subject = PassthroughSubject(onStartup: resumption)
        }
        let subjectPublisher = await subject.publisher().autoconnect()
        return subjectPublisher
    }
}
