//
//  ThrottleDemand.swift
//  
//
//  Created by Van Simmons on 7/4/22.
//
extension Publisher {
    func throttleDemand(
        interval: Duration
    ) -> Self {
        self.zip(Heartbeat(interval: interval)).map(\.0)
    }
}
