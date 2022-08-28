//
//  Publisher.swift
//  
//
//  Created by Van Simmons on 3/15/22.
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
public enum Demand: Equatable, Sendable {
    case more
    case done
}

public enum Completion: Sendable {
    case failure(Error)
    case cancelled
    case finished
}

public extension AsyncStream where Element: Sendable {
    enum Result: Sendable {
        case value(Element)
        case completion(Completion)
    }
}

public enum PublisherError: Swift.Error, Sendable, CaseIterable {
    case cancelled
    case completed
    case internalError
    case enqueueError
}

public struct Publisher<Output: Sendable>: Sendable {
    public typealias Downstream = @Sendable (AsyncStream<Output>.Result) async throws -> Demand
    private let call: @Sendable (Resumption<Void>, @escaping Downstream) -> Cancellable<Demand>

    internal init(
        _ call: @escaping @Sendable (Resumption<Void>, @escaping Downstream) -> Cancellable<Demand>
    ) {
        self.call = call
    }
}

public extension Publisher {
    @discardableResult
    func sink(onStartup: Resumption<Void>, _ downstream: @escaping Downstream) -> Cancellable<Demand> {
        self(onStartup: onStartup, downstream)
    }

    @discardableResult
    func callAsFunction(onStartup: Resumption<Void>, _ downstream: @escaping Downstream) -> Cancellable<Demand> {
        call(onStartup, { result in
            guard !Task.isCancelled else {
                return try await handleCancellation(of: downstream)
            }
            switch result {
                case let .value(value):
                    return try await downstream(.value(value))
                case let .completion(.failure(error)):
                    return try await downstream(.completion(.failure(error)))
                case .completion(.finished), .completion(.cancelled):
                    return try await downstream(result)
            }
        } )
    }

    @discardableResult
    func sink(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line,
        _ downstream: @escaping Downstream
    ) async -> Cancellable<Demand> {
        await self(function: function, file: file, line: line, downstream)
    }

    @discardableResult
    func callAsFunction(
        function: StaticString = #function,
        file: StaticString = #file,
        line: UInt = #line,
        _ downstream: @escaping Downstream
    ) async -> Cancellable<Demand> {
        var cancellable: Cancellable<Demand>!
        let _: Void = try! await withResumption(function: function, file: file, line: line) { resumption in
            cancellable = self(onStartup: resumption, downstream)
        }
        return cancellable
    }
}

extension Publisher {
    @Sendable private func lift(
        _ receiveCompletion: @escaping @Sendable (Completion) async throws -> Void,
        _ receiveValue: @escaping @Sendable (Output) async throws -> Void
    ) -> @Sendable (AsyncStream<Output>.Result) async throws -> Demand {
        { result in switch result {
            case let .value(value):
                try await receiveValue(value)
                return .more
            case let .completion(.failure(error)):
                do { try await receiveCompletion(.failure(error)); return .done }
                catch { throw error }
            case .completion(.finished):
                do { try await receiveCompletion(.finished); return .done }
                catch { return .done }
            case .completion(.cancelled):
                do { try await receiveCompletion(.cancelled); return .done }
                catch { return .done }
        } }
    }

    func sink(
        onStartup: Resumption<Void>,
        receiveValue: @escaping @Sendable (Output) async throws -> Void
    ) -> Cancellable<Demand> {
        sink(onStartup: onStartup, receiveCompletion: void, receiveValue: receiveValue)
    }

    func sink(
        receiveValue: @escaping @Sendable (Output) async throws -> Void
    ) async -> Cancellable<Demand> {
        await sink(receiveCompletion: void, receiveValue: receiveValue)
    }

    func sink(
        onStartup: Resumption<Void>,
        receiveCompletion: @escaping @Sendable (Completion) async throws -> Void,
        receiveValue: @escaping @Sendable (Output) async throws -> Void
    ) -> Cancellable<Demand> {
        sink(onStartup: onStartup, lift(receiveCompletion, receiveValue))
    }

    func sink(
        receiveCompletion: @escaping @Sendable (Completion) async throws -> Void,
        receiveValue: @escaping @Sendable (Output) async throws -> Void
    ) async -> Cancellable<Demand> {
        await sink(lift(receiveCompletion, receiveValue))
    }
}

func flattener<B>(
    _ downstream: @escaping Publisher<B>.Downstream
) -> Publisher<B>.Downstream {
    { b in switch b {
        case .completion(.finished):
            return .more
        case .value:
            return try await downstream(b)
        case .completion(.failure):
            return try await downstream(b)
        case .completion(.cancelled):
            return try await downstream(b)
    } }
}

func errorFlattener<B>(
    _ downstream: @escaping Publisher<B>.Downstream
) -> Publisher<B>.Downstream {
    { b in switch b {
        case .completion(.finished):
            return .more
        case .value:
            return try await downstream(b)
        case let .completion(.failure(error)):
            throw error
        case .completion(.cancelled):
            return try await downstream(b)
    } }
}

func handleCancellation<Output>(
    of downstream: @escaping Publisher<Output>.Downstream
) async throws -> Demand {
    _ = try await downstream(.completion(.cancelled))
    return .done
}
