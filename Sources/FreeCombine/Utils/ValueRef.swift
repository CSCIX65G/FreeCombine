//
//  ValueRef.swift
//  
//
//  Created by Van Simmons on 5/18/22.
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
public class ValueRef<Value> {
    enum Error: Swift.Error {
        case occupied
    }
    public private(set) var value: Value

    public init(value: Value) { self.value = value }

    @discardableResult
    public func set(value: Value) -> Value {
        let tmp = self.value
        self.value = value
        return tmp
    }

    public func get() -> Value {
        return self.value
    }
}

extension ValueRef {
    public func append<T>(_ t: T) throws -> Void where Value == [T] {
        value.append(t)
    }
}

