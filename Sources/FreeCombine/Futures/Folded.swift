//
//  Folded.swift
//  
//
//  Created by Van Simmons on 8/24/22.
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
public func fold<Output, OtherValue>(
    initial: Future<Output>,
    over other: Future<OtherValue>,
    with combiningFunction: @escaping @Sendable (Output, OtherValue) async -> Future<Output>
) -> Future<Output> {
    initial.flatMap { outputValue in
        let otherResultRef: ValueRef<Result<OtherValue, Swift.Error>> = .init(value: .failure(FutureError.internalError))
        _ = await Cancellable<Cancellable<Void>> { await other { otherResult in
            otherResultRef.set(value: otherResult)
        } }.join().result
        guard case let .success(otherValue) = otherResultRef.value else {
            return Failed(Output.self, error: FutureError.internalError)
        }
        return await combiningFunction(outputValue, otherValue)
    }
}

public func fold<Output, OtherValue>(
    _ futures: [Future<OtherValue>],
    with combiningFunction: @escaping @Sendable (Output, OtherValue) async -> Future<Output>
) -> Future<Output> {
    return Failed(Output.self, error: FutureError.internalError)
}
