//
//  UnsafeExpectation.swift
//  
//
//  Created by Van Simmons on 3/3/22.
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
