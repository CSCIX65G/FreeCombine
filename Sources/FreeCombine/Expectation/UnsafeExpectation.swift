//
//  UnsafeExpectation.swift
//  
//
//  Created by Van Simmons on 3/3/22.
//

public class UnsafeExpectation<Arg> {
    private let task: Task<Arg, Swift.Error>
    private let resumption: UnsafeContinuation<Arg, Swift.Error>

    public init() async {
        var localTask: Task<Arg, Swift.Error>!
        let localResumption: UnsafeContinuation<Arg, Swift.Error>!
        localResumption = await withCheckedContinuation { cc in
            localTask = Task<Arg, Swift.Error> {  try await withUnsafeThrowingContinuation { inner in
                cc.resume(returning: inner)
            } }
        }
        resumption = localResumption
        task = localTask
    }

    deinit {
        cancel()
    }

    public var isCancelled: Bool {
        task.isCancelled
    }

    public var result: Result<Arg, Swift.Error> {
        get async { await task.result }
    }

    public var value: Arg {
        get async throws { try await task.value }
    }

    public func cancel() -> Void {
        task.cancel()
    }

    public func complete(_ arg: Arg) -> Void {
        resumption.resume(returning: arg)
    }

    public func fail(_ error: Error) throws -> Void {
        resumption.resume(throwing: error)
    }
}

extension UnsafeExpectation where Arg == Void {
    public func complete() -> Void {
        resumption.resume(returning: ())
    }
}
