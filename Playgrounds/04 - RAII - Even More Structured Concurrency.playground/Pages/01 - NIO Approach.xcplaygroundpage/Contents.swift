//: [Previous](@previous)

/*:
[EventLoopPromise](https://github.com/apple/swift-nio/blob/e2c7fa4d4bda7cb7f4150b6a0bd69be2a54ef8c4/Sources/NIOCore/EventLoopFuture.swift#L159)
 ```
 /// A promise to provide a result later.
 ///
 /// This is the provider API for `EventLoopFuture<Value>`. If you want to return an
 /// unfulfilled `EventLoopFuture<Value>` -- presumably because you are interfacing to
 /// some asynchronous service that will return a real result later, follow this
 /// pattern:
 ///
 /// ```
 /// func someAsyncOperation(args) -> EventLoopFuture<ResultType> {
 ///     let promise = eventLoop.makePromise(of: ResultType.self)
 ///     someAsyncOperationWithACallback(args) { result -> Void in
 ///         // when finished...
 ///         promise.succeed(result)
 ///         // if error...
 ///         promise.fail(error)
 ///     }
 ///     return promise.futureResult
 /// }
 /// ```
 ///
 /// Note that the future result is returned before the async process has provided a value.
 ///
 /// It's actually not very common to use this directly. Usually, you really want one
 /// of the following:
 ///
 /// * If you have an `EventLoopFuture` and want to do something else after it completes,
 ///     use `.flatMap()`
 /// * If you already have a value and need an `EventLoopFuture<>` object to plug into
 ///     some other API, create an already-resolved object with
 ///     `eventLoop.makeSucceededFuture(result)` or `eventLoop.newFailedFuture(error:)`.
 ///
 /// - note: `EventLoopPromise` has reference semantics.

 ```
The reference semantics part is interesting.  This is NIO creating an actor...

[EventLoopFuture deinit](https://github.com/apple/swift-nio/blob/e2c7fa4d4bda7cb7f4150b6a0bd69be2a54ef8c4/Sources/NIOCore/EventLoopFuture.swift#L428)

```
 deinit {
     debugOnly {
         if let creation = eventLoop._promiseCompleted(futureIdentifier: _NIOEventLoopFutureIdentifier(self)) {
             if self._value == nil {
                 fatalError("leaking promise created at \(creation)", file: creation.file, line: creation.line)
             }
         } else {
             precondition(self._value != nil, "leaking an unfulfilled Promise")
         }
     }
 }
```
 */


//: [Next](@next)
