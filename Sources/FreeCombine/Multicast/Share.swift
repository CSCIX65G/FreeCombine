//
//  Share.swift
//  
//
//  Created by Van Simmons on 6/26/22.
//

public extension Publisher {
    func share() async -> Self {
        var subject: StateTask<DistributorState<Output>, DistributorState<Output>.Action>!
        let _: Void = try! await withResumption { resumption in
            subject = PassthroughSubject(onStartup: resumption)
        }
        return Deferred(from: subject.publisher())
    }
}
