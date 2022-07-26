### Functional Programming

* [Why Functional Programming Matters](https://www.cs.kent.ac.uk/people/staff/dat/miranda/whyfp90.pdf)

### Applied Functional Type Theory

* Sergei Winitzki's talk: [What I learned about functional programming while writing a book about it](https://youtu.be/T5oB8PZQNvY)

* [Sergei Winitzki's AMAZING book](https://leanpub.com/sofp) From the books description:

> After reading this book, you will understand everything in FP. Prove that your application's business logic satisfies the laws for free Tambara profunctor lens over a holographic co-product monoidal category (whatever that means), and implement the necessary code in Scala? Will be no problem for you.

*_ NB This statement is true._*

### Swift Concurrency

* [SE-296 Async/Await](https://github.com/apple/swift-evolution/blob/main/proposals/0296-async-await.md)
* [SE-298 AsyncSequence](https://github.com/apple/swift-evolution/blob/main/proposals/0298-asyncsequence.md)
* [SE-300 Continuations, Unsafe and Checked](https://github.com/apple/swift-evolution/blob/main/proposals/0300-continuation.md)
* [SE-302 Sendable](https://github.com/apple/swift-evolution/blob/main/proposals/0302-concurrent-value-and-concurrent-closures.md)
* [SE-314 AsyncStream](https://github.com/apple/swift-evolution/blob/main/proposals/0314-async-stream.md)

### Coroutines vs Fibers as Concurrency Constructs

* [Wikipedia article on Fibers](https://en.wikipedia.org/wiki/Fiber_(computer_science))
* [Discussion on Swift Evolution](https://forums.swift.org/t/why-stackless-async-await-for-swift/52785/7)
* [Fibers Under the Magnifying Glass](https://www.open-std.org/JTC1/SC22/WG21/docs/papers/2018/p1364r0.pdf)
* [Response to Fibers Under the Magnifying Glass](https://www.open-std.org/jtc1/sc22/wg21/docs/papers/2019/p0866r0.pdf)
* [Response to the Response to Fibers Under the Magnifying Glass](https://www.open-std.org/jtc1/sc22/wg21/docs/papers/2019/p1520r0.pdf)
* [Stackless Python](https://en.wikipedia.org/wiki/Stackless_Python)

### Readings on Concurrency in other languages

* [Sources for a lot of the design Swift Concurrency](https://forums.swift.org/t/concurrency-designs-from-other-communities/32389/16) From the thread:

    * [Discussion of implementation of concurrency in many languages](https://trio.discourse.group/c/structured-concurrency/7)
    * [Concurrency in Clojure](https://www.clojure.org/about/concurrent_programming)
    * [Concurrency in Rust](https://www.infoq.com/presentations/rust-2019/)
    * [Concurrency in Java (Project Loom)](https://cr.openjdk.java.net/~rpressler/loom/loom/sol1_part1.html)
    * [Concurrency in Dart](https://www.youtube.com/watch?v=vl_AaCgudcY)
    * [Concurrency in Go vs Concurrency in C#](https://medium.com/@alexyakunin/go-vs-c-part-1-goroutines-vs-async-await-ac909c651c11)
    * [Cool diagram showing some diffs](https://forums.swift.org/t/concurrency-designs-from-other-communities/32389/23)
    * [What color is your function](https://journal.stuffwithstuff.com/2015/02/01/what-color-is-your-function/)
    * [Function color is a myth](https://lukasa.co.uk/2016/07/The_Function_Colour_Myth/)
    * [Declarative Concurrency](https://www.cse.iitk.ac.in/users/satyadev/fall12/declarative-concurrency.html)
    * [The Research Language Koka](https://github.com/koka-lang/koka) with [Algebraic Effects](https://www.microsoft.com/en-us/research/wp-content/uploads/2016/08/algeff-tr-2016-v2.pdf)

### "Structured Concurrency" in Trio

* [Notes on structured concurrency](https://vorpus.org/blog/notes-on-structured-concurrency-or-go-statement-considered-harmful/) the original post that sparked Apple's approach of structured concurrency, in particular the idea that Task lifetimes should be organized hierarchically.
* [Timeouts and Cancellation for Humans](https://vorpus.org/blog/timeouts-and-cancellation-for-humans/) - influential on Apple's thinking

### Swift _Structured_ Concurrency (SSC) Proposals

* [SE-304 Structured Concurrency](https://github.com/apple/swift-evolution/blob/main/proposals/0304-structured-concurrency.md#proposed-solution) The original structured concurrency proposal from Apple and the solution they propose 
* [SE-306 Actors](https://github.com/apple/swift-evolution/blob/main/proposals/0306-actors.md)
* [SE-317 async let](https://github.com/apple/swift-evolution/blob/main/proposals/0317-async-let.md)

### Swift NIO and Structured Concurrency

* [Guidelines on NIO](https://github.com/swift-server/guides/blob/main/docs/concurrency-adoption-guidelines.md).  The official guidelines that implementors of server-side code are supposed to consider.
* [NIO Roadmap](https://forums.swift.org/t/future-of-swift-nio-in-light-of-concurrency-roadmap/41633/4).  Basically NIO needs custom executors to build its own version of a ThreadPool.

### Theory of Coroutines

* [Haskell's Coroutine Module](https://hackage.haskell.org/package/monad-coroutine-0.9.2/docs/Control-Monad-Coroutine.html)
* [Explanation of Coroutines in Haskell](https://www.schoolofhaskell.com/school/to-infinity-and-beyond/pick-of-the-week/coroutines-for-streaming)
* [Co: a dsl for coroutines](https://abhinavsarkar.net/posts/implementing-co-1/) From the link:

> Coroutine implementations often come with support for Channels for inter-coroutine communication. One coroutine can send a message over a channel, and another coroutine can receive the message from the same channel. Coroutines and channels together are an implementation of Communicating Sequential Processes (CSP)@5, a formal language for describing patterns of interaction in concurrent systems.

* [Communicating Sequential Processes](https://en.wikipedia.org/wiki/Communicating_sequential_processes) From the link:

> CSP message-passing fundamentally involves a rendezvous between the processes involved in sending and receiving the message, i.e. the sender cannot transmit a message until the receiver is ready to accept it. In contrast, message-passing in actor systems is fundamentally asynchronous, i.e. message transmission and reception do not have to happen at the same time, and senders may transmit messages before receivers are ready to accept them. These approaches may also be considered duals of each other, in the sense that rendezvous-based systems can be used to construct buffered communications that behave as asynchronous messaging systems, while asynchronous systems can be used to construct rendezvous-style communications by using a message/acknowledgement protocol to synchronize senders and receivers.

NB FreeCombine takes the message/acknowledgement protocol approach as primitive and builds out from there.  Differences between `StateTask` in FreeCombine and `actor` in Swift Concurrency:

1. `StateTask` allows `oneway` sends as well as synchronized sends
2. `StateTask` allows backpressure
3. `actor` has syntactical support in the language

### Theory of Streams

* [A Brief History of Streams](https://shonan.nii.ac.jp/archives/seminar/136/wp-content/uploads/sites/172/2018/09/a-brief-history-of-streams.pdf) - see especially page 21 comparing push and pull strategies
* [History of Haskell](https://www.microsoft.com/en-us/research/wp-content/uploads/2016/07/history.pdf) - see in particular Section 7.1 on Stream and Continuation-based I/O
* [Oleg Kiselyov's Stream Page](https://okmij.org/ftp/Streams.html)
* [Stream Fusion: From Lists to Streams to Nothing At All](https://github.com/bitemyapp/papers/blob/master/Stream%20Fusion:%20From%20Lists%20to%20Streams%20to%20Nothing%20At%20All.pdf)
* [All Things Flow: A History of Streams](https://okmij.org/ftp/Computation/streams-hapoc2021.pdf)
* [Exploiting Vector Instructions with Generalized Stream Fusion](https://cacm.acm.org/magazines/2017/5/216312-exploiting-vector-instructions-with-generalized-stream-fusion/fulltext)
* [Functional Stream Libraries and Fusion: What's Next?](https://okmij.org/ftp/meta-programming/shonan-streams.pdf)

### Theory of State

* [Lazy Functional State Threads](https://github.com/bitemyapp/papers/blob/master/Lazy%20Functional%20State%20Threads.pdf) - the original paper on the ST monad

### Generalized Functional Concurrency

* [Functional Pearls: A Poor Man's Concurrency Monad](https://github.com/bitemyapp/papers/blob/master/A%20Poor%20Man's%20Concurrency%20Monad.pdf)
* [Cheap (But Functional) Threads](https://github.com/bitemyapp/papers/blob/master/Cheap%20(But%20Functional)%20Threads.pdf)
* [Combining Events and Threads ...](https://github.com/bitemyapp/papers/blob/master/Combining%20Events%20and%20Threads%20for%20Scalable%20Network%20Services:%20Implementation%20and%20Evaluation%20of%20Monadic%2C%20Application-Level%20Concurrency%20Primitives.pdf)
* [Compiling with Continuations, Continued](https://github.com/bitemyapp/papers/blob/master/Compiling%20with%20Continuations%2C%20Continued.pdf)
* [Functional Reactive Programming from First Principles](https://github.com/bitemyapp/papers/blob/master/Functional%20Reactive%20Programming%20from%20First%20Principles.pdf)
* [Functional Reactive Programming, Continued](https://github.com/bitemyapp/papers/blob/master/Functional%20Reactive%20Programming%2C%20Continued.pdf)
* [Higher-order Functional Reactive Programming without Spacetime Leaks](https://github.com/bitemyapp/papers/blob/master/Higher-Order%20Functional%20Reactive%20Programming%20without%20Spacetime%20Leaks.pdf)
* [Push-Pull Functional Reactive Programming](https://github.com/bitemyapp/papers/blob/master/Push-pull%20functional%20reactive%20programming.pdf)
* [Stream Fusion on Haskell Unicode Strings](https://github.com/bitemyapp/papers/blob/master/Stream%20Fusion%20on%20Haskell%20Unicode%20Strings.pdf)

### Stream Libraries

* [Akka Streams](https://qconnewyork.com/ny2015/system/files/presentation-slides/AkkaStreamsQconNY.pdf) - important for the idea of dynamic push/pull mode.  See especially starting on page 29.
* Conversation on Combine and Async/Await 
    * [Part 1](https://iosdevelopers.slack.com/archives/C0AET0JQ5/p1623102144192300)
    * [Part 2](https://iosdevelopers.slack.com/archives/C0AET0JQ5/p1623177619245300?thread_ts=1623102144.192300&cid=C0AET0JQ5)

### Odds and Ends

* [Resource Acquisition is Initialization](https://en.wikipedia.org/wiki/Resource_acquisition_is_initialization)
* [Actor-isolation and Executors](https://github.com/apple/swift-evolution/blob/main/proposals/0338-clarify-execution-non-actor-async.md)
* [EventLoopPromise](https://github.com/apple/swift-nio/blob/e2c7fa4d4bda7cb7f4150b6a0bd69be2a54ef8c4/Sources/NIOCore/EventLoopFuture.swift#L159)
* [EventLoopFuture deinit](https://github.com/apple/swift-nio/blob/e2c7fa4d4bda7cb7f4150b6a0bd69be2a54ef8c4/Sources/NIOCore/EventLoopFuture.swift#L428)
* [Strema a functional language targeting the JSVM](https://gilmi.gitlab.io/strema/)
