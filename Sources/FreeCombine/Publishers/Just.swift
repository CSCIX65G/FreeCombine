//
//  Just.swift
//  
//
//  Created by Van Simmons on 3/15/22.
//
public func Just<Element>(
    onCancel: @Sendable @escaping () -> Void = { },
    _ a: Element
) -> Publisher<Element> {
    .init(onCancel: onCancel, a)
}

public extension Publisher {
    init(
        onCancel: @Sendable @escaping () -> Void = { },
        _ a: Output
    ) {
        self = .init { continuation, downstream in
            Task { await withTaskCancellationHandler(handler: onCancel) {
                continuation?.resume()
                guard !Task.isCancelled else { return .done }
                return await downstream(.value(a)) == .more ? await downstream(.terminated) : .done
            } }
        }
    }
}

public func Just<Element>(
    onCancel: @Sendable @escaping () -> Void = { },
    _ a: AsyncStream<Element>.Result
) -> Publisher<Element> {
    .init(onCancel: onCancel, a)
}

public extension Publisher {
    init(
        onCancel: @Sendable @escaping () -> Void = { },
        _ result: AsyncStream<Output>.Result
    ) {
        self = .init { continuation, downstream in
            Task { await withTaskCancellationHandler(handler: onCancel) {
                continuation?.resume()
                guard !Task.isCancelled else { return .done }
                return await downstream(result) == .more ? await downstream(.terminated) : .done
            } }
        }
    }
}
