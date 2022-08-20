//
//  Duration.swift
//  
//
//  Created by Van Simmons on 5/24/22.
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
