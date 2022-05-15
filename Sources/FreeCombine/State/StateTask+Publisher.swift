//
//  StateTask+Publisher.swift
//  
//
//  Created by Van Simmons on 5/15/22.
//
public extension StateTask {
    func publisher<Output: Sendable>(
        onCancel: @Sendable @escaping () -> Void = { }
    ) -> Publisher<Output> where State == DistributorState<Output>, Action == DistributorState<Output>.Action {
        .init(onCancel: onCancel, stateTask: self)
    }
}
