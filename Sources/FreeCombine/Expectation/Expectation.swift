//
//  Expectation.swift
//  
//
//  Created by Van Simmons on 1/28/22.
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
import Atomics

public class Expectation<Arg> {
    public enum Error: Swift.Error, Equatable {
        case alreadyCancelled
        case alreadyCompleted
        case alreadyFailed
        case cancelled
        case timedOut
        case internalInconsistency
    }

    public enum Status: UInt8, Equatable, RawRepresentable {
        case cancelled
        case completed
        case waiting
        case failed
    }

    private let atomic = ManagedAtomic<UInt8>(Status.waiting.rawValue)
    private(set) var resumption: Resumption<Arg>
    private let cancellable: Cancellable<Arg>
    public let function: StaticString
    public let file: StaticString
    public let line: UInt
    public let deinitBehavior: DeinitBehavior

    public init(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line,
        deinitBehavior: DeinitBehavior = .assert
    ) async {
        var localCancellable: Cancellable<Arg>!
        self.function = function
        self.file = file
        self.line = line
        self.deinitBehavior = deinitBehavior
        self.resumption = try! await withResumption(file: file, line: line, deinitBehavior: deinitBehavior) { outer in
            localCancellable = .init {
                do { return try await withResumption(file: file, line: line, deinitBehavior: deinitBehavior, outer.resume) }
                catch { throw error }
            }
        }
        self.cancellable = localCancellable
    }

    deinit {
        let shouldCancel = status == .waiting
        switch deinitBehavior {
            case .assert:
                assert(!shouldCancel, "ABORTING DUE TO LEAKED \(type(of: Self.self))  CREATED in \(function) @ \(file): \(line)")
            case .logAndCancel:
                if shouldCancel { print("CANCELLING LEAKED \(type(of: Self.self))  CREATED in \(function) @ \(file): \(line)") }
            case .silentCancel:
                ()
        }
        if shouldCancel { try? cancel() }
    }

    private func set(status newStatus: Status) throws -> Resumption<Arg> {
        let (success, original) = atomic.compareExchange(
            expected: Status.waiting.rawValue,
            desired: newStatus.rawValue,
            ordering: .sequentiallyConsistent
        )
        guard success else {
            switch original {
                case Status.completed.rawValue: throw Error.alreadyCompleted
                case Status.cancelled.rawValue: throw Error.alreadyCancelled
                case Status.failed.rawValue: throw Error.alreadyFailed
                default: throw Error.internalInconsistency
            }
        }
        return resumption
    }

    public var status: Status {
        .init(rawValue: atomic.load(ordering: .sequentiallyConsistent))!
    }

    public var isCancelled: Bool {
        cancellable.isCancelled
    }

    public var result: Result<Arg, Swift.Error> {
        get async { await cancellable.result }
    }
    
    public var value: Arg {
        get async throws { try await cancellable.value  }
    }

    public func cancel() throws {
        try set(status: .cancelled).resume(throwing: Error.cancelled)
    }
    public func complete(_ arg: Arg) throws {
        try set(status: .completed).resume(returning: arg)
    }
    func fail(_ error: Swift.Error) throws {
        try set(status: .failed).resume(throwing: error)
    }
}

extension Expectation where Arg == Void {
    public func complete() async throws -> Void {
        try complete(())
    }
}
