//
//  Zipped.swift
//  
//
//  Created by Van Simmons on 5/8/22.
//

public func Zipped<Left, Right>(
    onCancel: @escaping () -> Void = { },
    _ left: Publisher<Left>,
    _ right: Publisher<Right>
) -> Publisher<(Left, Right)> {
    zip(onCancel: onCancel, left, right)
}

public func zip<Left, Right>(
    onCancel: @escaping () -> Void = { },
    _ left: Publisher<Left>,
    _ right: Publisher<Right>
) -> Publisher<(Left, Right)> {
    .init(
        initialState: ZipState<Left, Right>.create(left: left, right: right),
        buffering: .bufferingOldest(2),
        onCancel: onCancel,
        onCompletion: ZipState<Left, Right>.complete,
        operation: ZipState<Left, Right>.reduce
    )
}

public extension Publisher {
    func zip<Other>(
        onCancel: @escaping () -> Void = { },
        _ other: Publisher<Other>
    ) -> Publisher<(Output, Other)> {
        Zipped(onCancel: onCancel, self, other)
    }
}
