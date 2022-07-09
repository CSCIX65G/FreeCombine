//
//  DelayEachDemand.swift
//  
//
//  Created by Van Simmons on 7/9/22.
//

extension Publisher {
    func delayEachDemand(
        interval: Duration
    ) -> Self {
        .init { resumption, downstream in
            self(onStartup: resumption) { r in
                let demand = try await downstream(r)
                guard demand != .done else { return demand }
                try await Task.sleep(nanoseconds: interval.inNanoseconds)
                return demand
            }
        }
    }
}
