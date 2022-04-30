//
//  EffectfulSemaphore.swift
//  
//
//  Created by Van Simmons on 4/24/22.
//

public actor EffectfulSemaphore {
    let continuation: UnsafeContinuation<() -> Void, Never>
    var count: Int
    var effect: () -> Void = { }

    public init(continuation: UnsafeContinuation<() -> Void, Never>, count: Int) {
        self.continuation = continuation
        self.count = count
    }

    public func decrement(with effect: (() -> Void)? = .none) throws {
        guard count > 0 else {
            fatalError("Semaphore over decremented")
        }
        count -= 1
        if let effect = effect {
            self.effect = { self.effect(); effect() }
        }
        if count == 0 {
            continuation.resume(returning: self.effect)
        }
    }
}
