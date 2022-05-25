//
//  Duration.swift
//  
//
//  Created by Van Simmons on 5/24/22.
//
public enum Duration {
    case seconds(UInt64)
    case milliseconds(UInt64)
    case microseconds(UInt64)
    case nanoseconds(UInt64)

    public var inNanoseconds: UInt64 {
        switch self {
            case .seconds(let seconds):
                return seconds * 1_000_000_000
            case .milliseconds(let milliseconds):
                return milliseconds * 1_000_000
            case .microseconds(let microseconds):
                return microseconds * 1_000
            case .nanoseconds(let nanoseconds):
                return nanoseconds
        }
    }
}
