### Functional Programming

[Why Functional Programming Matters](https://www.cs.kent.ac.uk/people/staff/dat/miranda/whyfp90.pdf)

### Applied Functional Type Theory

[What I learned about functional programming while writing a book about it](https://youtu.be/T5oB8PZQNvY)

[Sergei Winitzki's AMAZING book](https://leanpub.com/sofp)
> After reading this book, you will understand everything in FP. Prove that your application's business logic satisfies the laws for free Tambara profunctor lens over a holographic co-product monoidal category (whatever that means), and implement the necessary code in Scala? Will be no problem for you.

^^^ This statement is true.

### Swift Concurrency
[SE-296 Async/Await](https://github.com/apple/swift-evolution/blob/main/proposals/0296-async-await.md)
[SE-298 AsyncSequence](https://github.com/apple/swift-evolution/blob/main/proposals/0298-asyncsequence.md)
[SE-300 Continuations, Unsafe and Checked](https://github.com/apple/swift-evolution/blob/main/proposals/0300-continuation.md)
[SE-302 Sendable](https://github.com/apple/swift-evolution/blob/main/proposals/0302-concurrent-value-and-concurrent-closures.md)
[SE-314 AsyncStream](https://github.com/apple/swift-evolution/blob/main/proposals/0314-async-stream.md)

### Swift _Structured_ Concurrency
[SE-304 Structured Concurrency](https://github.com/apple/swift-evolution/blob/main/proposals/0304-structured-concurrency.md#proposed-solution) The original structured concurrency proposal from Apple and the solution they propose 
[SE-306 Actors](https://github.com/apple/swift-evolution/blob/main/proposals/0306-actors.md)
[SE-317 async let](https://github.com/apple/swift-evolution/blob/main/proposals/0317-async-let.md)

[Sources for a lot of the design](https://forums.swift.org/t/concurrency-designs-from-other-communities/32389/16)

[Notes on structured concurrency](https://vorpus.org/blog/notes-on-structured-concurrency-or-go-statement-considered-harmful/) the original post that sparked Apple's approach of structured concurrency, in particular the idea that Task lifetimes should be organized hierarchically.

[Timeouts and Cancellation for Humans](https://vorpus.org/blog/timeouts-and-cancellation-for-humans/) - influential on Apple's thinking

[Guidelines on NIO](https://github.com/swift-server/guides/blob/main/docs/concurrency-adoption-guidelines.md).  The official guidelines that implementors of server-side code are supposed to consider.

[NIO Roadmap](https://forums.swift.org/t/future-of-swift-nio-in-light-of-concurrency-roadmap/41633/4).  Basically NIO needs custom executors to build its own version of a ThreadPool.

### Theory of Coroutines
[Haskell's Coroutine Module](https://hackage.haskell.org/package/monad-coroutine-0.9.2/docs/Control-Monad-Coroutine.html)
[Explanation of Coroutines in Haskell](https://www.schoolofhaskell.com/school/to-infinity-and-beyond/pick-of-the-week/coroutines-for-streaming)
[Co: a dsl for coroutines](https://abhinavsarkar.net/posts/implementing-co-1/)
> Coroutine implementations often come with support for Channels for inter-coroutine communication. One coroutine can send a message over a channel, and another coroutine can receive the message from the same channel. Coroutines and channels together are an implementation of Communicating Sequential Processes (CSP)@5, a formal language for describing patterns of interaction in concurrent systems.

[Communicating Sequential Processes](https://en.wikipedia.org/wiki/Communicating_sequential_processes)
> CSP message-passing fundamentally involves a rendezvous between the processes involved in sending and receiving the message, i.e. the sender cannot transmit a message until the receiver is ready to accept it. In contrast, message-passing in actor systems is fundamentally asynchronous, i.e. message transmission and reception do not have to happen at the same time, and senders may transmit messages before receivers are ready to accept them. These approaches may also be considered duals of each other, in the sense that rendezvous-based systems can be used to construct buffered communications that behave as asynchronous messaging systems, while asynchronous systems can be used to construct rendezvous-style communications by using a message/acknowledgement protocol to synchronize senders and receivers.

NB FreeCombine takes the message/acknowledgement protocol approach as primitive and builds out from there.

### Theory of Streams
* [A Brief History of Streams](https://shonan.nii.ac.jp/archives/seminar/136/wp-content/uploads/sites/172/2018/09/a-brief-history-of-streams.pdf) - see especially page 21 comparing push and pull strategies

[History of Haskell](https://www.microsoft.com/en-us/research/wp-content/uploads/2016/07/history.pdf) - see in particular Section 7.1 on Stream and Continuation-based I/O

* [Oleg Kiselyov's Stream Page](https://okmij.org/ftp/Streams.html)

* [Stream Fusion: From Lists to Streams to Nothing At All](https://github.com/bitemyapp/papers/blob/master/Stream%20Fusion:%20From%20Lists%20to%20Streams%20to%20Nothing%20At%20All.pdf)

* [All Things Flow: A History of Streams](https://okmij.org/ftp/Computation/streams-hapoc2021.pdf)

* [Exploiting Vector Instructions with Generalized Stream Fusion](https://cacm.acm.org/magazines/2017/5/216312-exploiting-vector-instructions-with-generalized-stream-fusion/fulltext)

* [Functional Stream Libraries and Fusion: What's Next?](https://okmij.org/ftp/meta-programming/shonan-streams.pdf)

### Theory of State
[Lazy Functional State Threads](https://github.com/bitemyapp/papers/blob/master/Lazy%20Functional%20State%20Threads.pdf) - the original paper on the ST monad

### Generalized Functional Concurrency
https://github.com/bitemyapp/papers/blob/master/A%20Poor%20Man's%20Concurrency%20Monad.pdf
https://github.com/bitemyapp/papers/blob/master/Cheap%20(But%20Functional)%20Threads.pdf
https://github.com/bitemyapp/papers/blob/master/Combining%20Events%20and%20Threads%20for%20Scalable%20Network%20Services:%20Implementation%20and%20Evaluation%20of%20Monadic%2C%20Application-Level%20Concurrency%20Primitives.pdf
https://github.com/bitemyapp/papers/blob/master/Compiling%20with%20Continuations%2C%20Continued.pdf
https://github.com/bitemyapp/papers/blob/master/Functional%20Reactive%20Programming%20from%20First%20Principles.pdf
https://github.com/bitemyapp/papers/blob/master/Functional%20Reactive%20Programming%2C%20Continued.pdf
https://github.com/bitemyapp/papers/blob/master/Higher-Order%20Functional%20Reactive%20Programming%20without%20Spacetime%20Leaks.pdf
https://github.com/bitemyapp/papers/blob/master/Push-pull%20functional%20reactive%20programming.pdf
https://github.com/bitemyapp/papers/blob/master/Stream%20Fusion%20on%20Haskell%20Unicode%20Strings.pdf

### Stream Libraries
[Akka Streams](https://qconnewyork.com/ny2015/system/files/presentation-slides/AkkaStreamsQconNY.pdf) - important for the idea of dynamic push/pull mode.  See especially starting on page 29.

[Conversation on Combine](https://iosdevelopers.slack.com/archives/C0AET0JQ5/p1623102144192300)
[And](https://iosdevelopers.slack.com/archives/C0AET0JQ5/p1623177619245300?thread_ts=1623102144.192300&cid=C0AET0JQ5)

### Concepts

[Resource Acquisition is Initialization](https://en.wikipedia.org/wiki/Resource_acquisition_is_initialization)

### Odds and Ends
[Actor-isolation and Executors](https://github.com/apple/swift-evolution/blob/main/proposals/0338-clarify-execution-non-actor-async.md)
[EventLoopPromise](https://github.com/apple/swift-nio/blob/e2c7fa4d4bda7cb7f4150b6a0bd69be2a54ef8c4/Sources/NIOCore/EventLoopFuture.swift#L159)
[EventLoopFuture deinit](https://github.com/apple/swift-nio/blob/e2c7fa4d4bda7cb7f4150b6a0bd69be2a54ef8c4/Sources/NIOCore/EventLoopFuture.swift#L428)
