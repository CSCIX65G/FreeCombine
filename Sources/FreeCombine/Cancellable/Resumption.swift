//
//  Resumption.swift
//  
//
//  Created by Van Simmons on 6/15/22.
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
@preconcurrency import Atomics

public final class Resumption<Output: Sendable>: Sendable {
    public enum Error: Swift.Error {
        case leaked
        case alreadyResumed
    }

    private let deallocGuard: ManagedAtomic<Bool>
    private let continuation: UnsafeContinuation<Output, Swift.Error>

    public let function: StaticString
    public let file: StaticString
    public let line: UInt

    init(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line,
        continuation: UnsafeContinuation<Output, Swift.Error>
    ) {
        self.deallocGuard = ManagedAtomic<Bool>(false)
        self.function = function
        self.file = file
        self.line = line
        self.continuation = continuation
    }

    deinit {
        assert(
            deallocGuard.load(ordering: .sequentiallyConsistent),
            "ABORTING DUE TO LEAKED \(type(of: Self.self)):\(self)  CREATED in \(function) @ \(file): \(line)"
        )
        if !deallocGuard.load(ordering: .sequentiallyConsistent) {
            continuation.resume(throwing: Error.leaked)
        }
    }

    public func resume(returning output: Output) -> Void {
        let (success, _) = deallocGuard.compareExchange(expected: false, desired: true, ordering: .sequentiallyConsistent)
        assert(success, "\(type(of: Self.self)) FAILED. ALREADY RESUMED \(type(of: Self.self)):\(self)  CREATED in \(function) @ \(file): \(line)")
        continuation.resume(returning: output)
    }

    public func resume(throwing error: Swift.Error) -> Void {
        let (success, _) = deallocGuard.compareExchange(expected: false, desired: true, ordering: .sequentiallyConsistent)
        assert(success, "\(type(of: Self.self)) FAILED. ALREADY RESUMED \(type(of: Self.self)):\(self)  CREATED in \(function) @ \(file): \(line)")
        continuation.resume(throwing: error)
    }
}

extension Resumption where Output == Void {
    public func resume() -> Void {
        let (success, _) = deallocGuard.compareExchange(expected: false, desired: true, ordering: .acquiring)
        defer { deallocGuard.store(true, ordering: .releasing) }
        assert(success, "RESUMPTION FAILED TO RETURN. ALREADY RESUMED")
        continuation.resume(returning: ())
    }
}

public func withResumption<Output>(
    function: StaticString = #function,
    file: StaticString = #file,
    line: UInt = #line,
    _ resume: (Resumption<Output>) -> Void
) async throws -> Output {
    try await withUnsafeThrowingContinuation { (continuation: UnsafeContinuation<Output, Swift.Error>) -> Void in
        resume(.init(
            function: function,
            file: file,
            line: line,
            continuation: continuation
        ))
    }
}
