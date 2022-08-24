//
//  Cancellable.swift
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
@preconcurrency import Atomics

public enum DeinitBehavior: Sendable {
    case assert
    case logAndCancel
    case silentCancel
}

// Can't be a protocol bc we have to implement deinit
public final class Cancellable<Output: Sendable>: Sendable {
    private let task: Task<Output, Swift.Error>
    private let deallocGuard: ManagedAtomic<Bool>

    public let function: StaticString
    public let file: StaticString
    public let line: UInt
    public let deinitBehavior: DeinitBehavior

    public var isCancelled: Bool { task.isCancelled }
    public var isCompleting: Bool { deallocGuard.load(ordering: .sequentiallyConsistent) }
    public var value: Output { get async throws { try await task.value } }
    public var result: Result<Output, Swift.Error> {  get async { await task.result } }

    @Sendable public func cancel() -> Void {
        guard !isCompleting else { return }
        task.cancel()
    }
    @Sendable public func cancelAndAwaitValue() async throws -> Output {
        cancel()
        return try await task.value
    }
    @Sendable public func cancelAndAwaitResult() async -> Result<Output, Swift.Error> {
        cancel()
        return await task.result
    }

    init(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line,
        deinitBehavior: DeinitBehavior = .assert,
        operation: @escaping @Sendable () async throws -> Output
    ) {
        let atomic = ManagedAtomic<Bool>(false)
        self.deallocGuard = atomic
        self.function = function
        self.file = file
        self.line = line
        self.deinitBehavior = deinitBehavior
        self.task = .init {
            do {
                let retVal = try await operation()
                atomic.store(true, ordering: .sequentiallyConsistent)
                return retVal
            }
            catch {
                atomic.store(true, ordering: .sequentiallyConsistent)
                throw error
            }
        }
    }

    deinit {
        let shouldCancel = !(isCompleting || task.isCancelled)
        switch deinitBehavior {
            case .assert:
                assert(!shouldCancel, "ABORTING DUE TO LEAKED \(type(of: Self.self))  CREATED in \(function) @ \(file): \(line)")
            case .logAndCancel:
                if shouldCancel { print("CANCELLING LEAKED \(type(of: Self.self))  CREATED in \(function) @ \(file): \(line)") }
            case .silentCancel:
                ()
        }
        if shouldCancel { task.cancel() }
    }
}

extension Cancellable {
    func store(in cancellables: inout Set<Cancellable<Output>>) {
        cancellables.insert(self)
    }
}

extension Cancellable: Hashable {
    public static func == (lhs: Cancellable<Output>, rhs: Cancellable<Output>) -> Bool {
        lhs.task == rhs.task
    }
    public func hash(into hasher: inout Hasher) {
        hasher.combine(self)
    }
}

public extension Cancellable {
    static func join<B>(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line,
        _ outer: Cancellable<Cancellable<B>>
    ) -> Cancellable<B> {
        .init(file: file, line: line, operation: {
            try await withTaskCancellationHandler(
                operation: {
                    return try await outer.value.value
                },
                onCancel: {
                    Task { try! await outer.value.cancel() }
                }
            )
        })
    }

    static func join(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line,
        deinitBehavior: DeinitBehavior = .assert,
        _ generator: @escaping () async throws -> Cancellable<Output>
    ) async throws -> Cancellable<Output> {
        var returnValue: Cancellable<Output>!
        let _: Void = try await withResumption(file: file, line: line, deinitBehavior: deinitBehavior) { resumption in
            returnValue = .init(file: file, line: line, operation: {
                let outer = try await generator()
                return try await withTaskCancellationHandler(
                    operation: {
                        resumption.resume()
                        return try await outer.value
                    },
                    onCancel: {
                        outer.cancel()
                    }
                )
            })
        }
        return returnValue
    }

    func map<B>(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line,
        _ transform: @escaping (Output) async -> B
    ) -> Cancellable<B> {
        let inner = self
        return .init(file: file, line: line) {
            try await withTaskCancellationHandler(
                operation: {
                    try await transform(inner.value)
                },
                onCancel: {
                    self.cancel()
                }
            )
        }
    }

    func join<B>(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line
    ) -> Cancellable<B> where Output == Cancellable<B> {
        Self.join(file: file, line: line, self)
    }

    func flatMap<B>(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line,
        _ transform: @escaping (Output) async -> Cancellable<B>
    ) -> Cancellable<B> {
        self.map(file: file, line: line, transform).join(file: file, line: line)
    }
}
