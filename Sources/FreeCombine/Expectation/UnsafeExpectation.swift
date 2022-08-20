//
//  UnsafeExpectation.swift
//  
//
//  Created by Van Simmons on 3/3/22.
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
public class UnsafeExpectation<Arg> {
    private let cancellable: Cancellable<Arg>
    private let resumption: UnsafeContinuation<Arg, Swift.Error>

    public init() async {
        var localCancellable: Cancellable<Arg>!
        resumption = await withCheckedContinuation { cc in
            localCancellable = .init {  try await withUnsafeThrowingContinuation { inner in
                cc.resume(returning: inner)
            } }
        }
        cancellable = localCancellable
    }

    deinit {
        cancel()
    }

    public var isCancelled: Bool { cancellable.isCancelled }
    public var value: Arg { get async throws { try await cancellable.value } }
    public var result: Result<Arg, Swift.Error> { get async { await cancellable.result } }

    public func cancel() -> Void { cancellable.cancel() }
    public func complete(_ arg: Arg) -> Void { resumption.resume(returning: arg) }
    public func fail(_ error: Error) throws -> Void { resumption.resume(throwing: error) }
}

extension UnsafeExpectation where Arg == Void {
    public func complete() -> Void { resumption.resume(returning: ()) }
}
