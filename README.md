[edit](https://github.com/CSCIX65G/FreeCombine/edit/gh-pages/README.md)

# FreeCombine

Note that this README is still under construction. The places herein where I refer to the Playgrounds and Examples section refers to areas that I still need to complete (especially the Examples).

## TL;DR

FreeCombine is a streaming library designed to implement every Publisher operator in Apple's Combine framework - only it does it in `async` context and allows `async` functions to be passed in whereever Combine accepts a function as an argument.  

NB this does _NOT_ mean that the semantics or syntax of each operator will stay exactly the same.  Implementing a streaming library using Swift Concurrency means that some things _must_ change semantically to prevent data races and task leaks.

Additionally, FreeCombine takes a different stance on how Publishers are constructed - we don't use protocols, instead we use concrete types.  This also leads to code that looks and feels almost the same as Combine, but which is slightly different.  To facilitate the use of FreeCombine, several liberties have been taken with Swift syntax to make FreeCombine appear as much as possible like Combine.

An example of a change in syntax is `map`.  Here's the Combine definition of `map` on a Publisher:
```
func map<T>(_ transform: @escaping (Self.Output) -> T) -> Publishers.Map<Self, T>
```
Here's the same function on Publisher in FreeCombine:
```
func map<B>( _ f: @escaping (Output) async -> B) -> Publisher<B>
```
Note two significant changes:

1. FreeCombine returns a standard Publisher, not a special Publishers.Map
1. FreeCombine accepts an `async` transform function.

These differences are pervasive throughout the library and are explained in much more detail below and in the Example and explanatory Playgrounds in this repository.

But _really_ TL;DR... This is an async version of Combine.

## First Example
Here's a silly example of Combine that you can cut and paste into any playground.  The idea is to show the use of Subjects, Sequences, zip, merge, map, and replaceError all working together:
```swift
import Combine
func combineVersion() {
    let subject1 = Combine.PassthroughSubject<Int, Error>()
    let subject2 = Combine.PassthroughSubject<String, Error>()
    
    let seq1 = "abcdefghijklmnopqrstuvwxyz".publisher
    let seq2 = (1 ... 100).publisher
    
    let z1 = seq1.zip(seq2)
        .map { left, right in String(left) + String(right) }
    let m1 = subject1
        .map(String.init)
        .mapError { _ in fatalError() }
        .merge(with: subject2)
        .replaceError(with: "")
    
    let m2 = z1.merge(with: m1)
    let cancellable = m2.sink { value in
        print("Combine received: \(value)")
    }
    
    subject1.send(14)
    subject2.send("hello, combined world!")
    subject1.send(completion: .finished)
    subject2.send(completion: .finished)
    cancellable.cancel()
}
combineVersion()
```
This produces the following output.  Note that `14` and `hello, combined world!` always appear at the end:
```
Combine received: a1
Combine received: b2
Combine received: c3
Combine received: d4
Combine received: e5
Combine received: f6
Combine received: g7
Combine received: h8
Combine received: i9
Combine received: j10
Combine received: k11
Combine received: l12
Combine received: m13
Combine received: n14
Combine received: o15
Combine received: p16
Combine received: q17
Combine received: r18
Combine received: s19
Combine received: t20
Combine received: u21
Combine received: v22
Combine received: w23
Combine received: x24
Combine received: y25
Combine received: z26
Combine received: 14
Combine received: hello, combined world!
```
Below is the same example using FreeCombine.  This can also be cut and pasted into a Playground which has access to FreeCombine.
```swift
import FreeCombine
import _Concurrency
func freeCombineVersion() {
    Task {
        let subject1 = try await FreeCombine.PassthroughSubject(Int.self)
        let subject2 = try await FreeCombine.PassthroughSubject(String.self)
        
        let seq1 = "abcdefghijklmnopqrstuvwxyz".asyncPublisher
        let seq2 = (1 ... 100).asyncPublisher
        
        let z1 = seq1.zip(seq2)
            .map { left, right in String(left) + String(right) }
        let m1 = subject1.asyncPublisher
            .map(String.init)
            .mapError { _ in fatalError() }
            .merge(with: subject2.asyncPublisher)
            .replaceError(with: "")
        
        
        let m2 = z1.merge(with: m1)
        let cancellable = await m2.sink { value in
            guard case let .value(value) = value else { return .more }
            print("FreeCombine received: \(value)")
            return .more
        }
        
        try await subject1.send(14)
        try await subject2.send("hello, combined world!")
        try await subject1.finish()
        try await subject2.finish()
        _ = await cancellable.result
    }
}
freeCombineVersion()
```
Note the following differences:

1. The PassthroughSubject calls take the Output type as a function parameter rather than as a generic type parameter.
1. The PasshthroughSubject calls do not require a Failure type. In the manner of NIO and Concurrency, all Subjects and Publishers in FreeCombine use [imprecise Error handling](https://forums.swift.org/t/precise-error-typing-in-swift/52045) and therefore use `Swift.Error` as the error type.
1. The Subjects require you to ask them for a `asyncPublisher`.  In FreeCombine, Subject _cannot be_ a Publisher, because Publisher _is not_ a protocol.
1. The Sequence types: `Array` and `String` have been extended with `asyncPublisher` rather than just `publisher`
1. The cancellable and the subjects at the end are all awaited instead of simply discarded.

All of these differences are explained in this repo in the `Playgrounds` section.  If you are not interested in the _why?'s_ but only in the _how?'s_, the `Examples` section is what you want.  It consists of playgrounds with example use of every operator, many in a variety of contexts, and is there for the "just-show-me-how-to-use-it" crowd.

The code above produces the output below. Observe how the `zip` does not block at all and the values `14` and `hello, combined world!` are emitted asynchronously into the stream as they occur. And unlike the Combine example, _they actually do occur asyncronously_ rather than at the end of the other streams.  The location in the output where you receive those two values if you run this code will vary and different runs of the same code may place them in different places.
```
FreeCombine received: a1
FreeCombine received: b2
FreeCombine received: 14
FreeCombine received: c3
FreeCombine received: d4
FreeCombine received: e5
FreeCombine received: hello, combined world!
FreeCombine received: f6
FreeCombine received: g7
FreeCombine received: h8
FreeCombine received: i9
FreeCombine received: j10
FreeCombine received: k11
FreeCombine received: l12
FreeCombine received: m13
FreeCombine received: n14
FreeCombine received: o15
FreeCombine received: p16
FreeCombine received: q17
FreeCombine received: r18
FreeCombine received: s19
FreeCombine received: t20
FreeCombine received: u21
FreeCombine received: v22
FreeCombine received: w23
FreeCombine received: x24
FreeCombine received: y25
FreeCombine received: z26
```
# The Long Version

## Like Combine. Only free. And concurrent.

FreeCombine is a functional streaming library for the Swift language.  

Functional streaming comes in two forms: push and pull.  FreeCombine is pull.  RxSwift and ReactiveSwift are push.  Combine is both, but primarily pull, in that the vast majority of use cases utilize only the push mode.  If you are curious about the differences between the two, a good introduction is this one on [the Akka Streams library](https://qconnewyork.com/ny2015/system/files/presentation-slides/AkkaStreamsQconNY.pdf) which is both push and pull and can change between the two dynamically (Pages 29-33 are especially informative).  

As an aside, if you have ever wondered what a Subscription is in Combine, it's the implementation of pull semantics.  Any use of `sink` or `assign` puts the stream into push mode and ignores Demand.  If you've never used `AnySubscriber` and have never written your own `Subscriber` implementation, then you've only been using Combine in push mode.  My experience is that this is the vast majority of Combine users. 

AsyncStream in Apple's Swift standard library is a _pull_ stream. Accordingly several things that seem natural in Combine turn out to have different meanings in AsyncStream (and are much more difficult to implement). In particular, having several downstream subscribers to the same stream is very complicated when compared to doing the same thing in a push environment.  AsyncStream conforms to AsyncSequence and all of the other conforming types to AsyncSequence are also pull-mode streams and therefore share the same semantics.

The difference between push and pull is really fundamental, yet in my experience, most users of Combine are surprised to learn that it exists.  It explains why, as of this writing in July '22, Swift Async Algorithms still lacks a `Subject`-like type. It's because `Subject`, `ConnectablePublisher` and operations like `throttle`, `delay` and `debounce` are really hard to get right in a pull system and they are much easier to implement in push systems.  OTOH, operations like `zip` are really hard to get right in a push system because they require the introduction of unbounded queues upstream. Unbounded queues are more than a little problematic if the user has not explicitly accounted for their presence.

While there are exceptions (Combine for example), streams in synchronous systems tend to be push, in asynchronous systems they tend to be pull. Different applications are better suited to one form of streaming than the other. The main differences lie in how the two modes treat combinators like zip or decombinators like Combine's Subject. A good summary of the differences is found in this presentation: [A Brief History of Streams](https://shonan.nii.ac.jp/archives/seminar/136/wp-content/uploads/sites/172/2018/09/a-brief-history-of-streams.pdf) - especially the table on page 21.  One interesting area of future development for FreeCombine is at the interface between synchronous and asynchronous context, for example, you would like your SwiftUI code to be only synchronous - a button tap should not (and really cannot) hang the UI, but you would like your application state to be maintained in async context.  More on this below.

All streaming libraries are written in the [Continuation Passing Style (CPS)](https://en.wikipedia.org/wiki/Continuation-passing_style).  Because of this they share certain operations for the Continuation type: map, flatMap, join, filter, reduce, et al.  (FWIW, everything you know Object-Oriented notation is also CPS just slightly disguised. This is shown Playground 2 in the Playgrounds directory).

Promise/Future systems are also written in CPS and as a result share many of the same operations.  FreeCombine incorporates NIO-style Promises and Futures almost by default as a result of FreeCombine's direct implemenation of CPS.  In FreeCombine's implementations of Publisher and Future, it is easy to read the relationship between the two directly from the type signatures. Futures can be thought of as "one-shot" streams, i.e. a stream which will only ever send exactly one element downstream, no more, no less.  In this paradigm, Promises can be seen to be the exact one-shot representation of Subject from the "normal" streaming world. If you find the concept of a "one-shot" stream odd, it is worth noting that the Swift Standard Library already has an exactly analogous notion in the type [CollectionOfOne](https://developer.apple.com/documentation/swift/collectionofone).

## What makes FreeCombine "Free"
So what makes FreeCombine different from AsyncSequence (and its support in Apple's swift-async-algorithms package)? And what do you mean by _free_ anyway?  

FreeCombine is "free" in the sense that it is:

* Protocol-free.
  * No use of protocols, only concrete types
  * Eager type erasure, no long nested types as seen in Combine.
  * Explicit implemenation of the continuation-passing style via the Publisher and StateTask types.
* Race-free.
  * Yield-free.
  * Sleep-free.
  * subscribeOn-free.  `subscribeOn`-like functionality is inherent in FreeCombine.  The race conditions it creates are prevented because continuations are only created after upstream continuations are guaranteed to exist and have started.  `subscribeOn` is guaranteed to be in the right async context.
  * All tests must demonstrate race-free operation by executing successfully for 10,000 repetitions under Xcode's `Run [Tests] Repeatedly` option.
* Leak-free.
  * ARC-like Task lifetimes
  * ARC-like Continuation lifetimes
  * Leaks of FreeCombine primitives are considered programmer error and are handled in a way similar to [leaks of NIO EventLoopPromises](https://github.com/apple/swift-nio/blob/48916a49afedec69275b70893c773261fdd2cfde/Sources/NIOCore/EventLoopFuture.swift#L431).
* Lock-free.
  * Uses queueing channels instead of locking channels
  * i.e. Blocking, not locking
  * No use of `os_unfair_lock` or its equivalent constructs in other operating systems 

The key take away here is: Protocol-free, race-free, leak-free, lock-free is the motto of the firm.

These "freedoms" imply the following specific restrictions on the implementation:

Don'ts:
* No use of `protocol`
* No use of `TaskGroup` or `async let`
* No use of `AsyncSequence`, use of concrete AsyncStreams only
* No use of `swift-async-algorithms` due to pervasive use of locking algorithms and AsyncSequence

Sort of Don'ts:
* Use of `for await` only in StateTask
* Use of `Task.init` only in Cancellable
* Use of `[Checked|Unsafe]Continuation.init` only in Resumption
* Use of `AsyncStream.init` only in Channel
* Use of `.unbounded` as a BufferingPolicy only in Channels which accept downstream-specific operations such as subscribe and unsubscribe.  Upstream operations such as `receiveValue` must be `.oldest(1)` except in specific cases like `throttle` where they may be `.newest(1)`.

In the immortal words of [John Hughes](https://www.cs.kent.ac.uk/people/staff/dat/miranda/whyfp90.pdf): 

> The functional programmer sounds rather like a medieval monk, denying himself the pleasures of life in the hope that it will make him virtuous. To those more interested in material benefits, these “advantages” are totally unconvincing.

That's not a bad description of what we are doing here.  :)

## So... Why are we doing this again?

For a long time I've been exploring the idea of what Apple's Swift Combine framework would look like if written without using protocols. The advent of Concurrency support in Swift 5.5 provided an impetus to complete that exploration. This repository represents the current state of that effort and consists of material that I intend to incorporate into classes I teach on iOS development at [Harvard](https://courses.dce.harvard.edu/?details&srcdb=202203&crn=33540) and at [Tufts](https://www.cs.tufts.edu/t/courses/description/fall2021/CS/151-02).

Ideally, this material would become the core of an expanded course on Functional Concurrent Programming using Swift, but that course is still fairly far off.  
  
Secondarily, this repo is our own feeble attempt to answer the following questions: 
  
1. Why does the use of protocols in things like Combine and AsyncSequence seem to produce much more complicated APIs than if the same APIs had been implemented with concrete types instead?
1. Why does Swift Concurrency seem to avoid the use of functional constructs like `map`, `flatMap`, and `zip` when dealing with generic types like Tasks, but to embrance them fully when dealing with generic types like `AsyncStream`? (not to mention more run-of-the-mill types like `Optional`, `Result`, and `Sequence`)
1. Why does AsyncSequence in Swift Concurrency have so many methods in common with Combine, yet the required parts of their protocols seem so different? 
1. Why is it that EventLoopFuture from Swift NIO shares so many methods with Publisher from Combine and AsyncSequence from the Swift standar library, but that Future in Combine looks so different from EventLoopFuture?
1. Why does Swift Concurrency seem to avoid the notion of a Future and its accompanying methods altogether?
1. Which elements of Swift Concurrency should be regarded as `primitive` and which are `compound`, (i.e. formed by composing the primitive elements)? And what does composition of these elements mean, anyway?
1. If, in Swift, we decorate "effectful" functions with keywords like `throws` and `async`, does that mean we can expect other kinds of effects to introduce additional keywords on function declaration?
1. Is there a general way of dealing with effects in Swift and what might such a mechanism look like?
1. Why does Swift's Structured Concurrency not have a set of primitives similar to (say) Haskell or Java?  In particular, why does it seem so difficult to use Structured Concurrency to write constructs like Haskell's [ST monad](https://hackage.haskell.org/package/base-4.3.1.0/docs/Control-Monad-ST.html), [MVar](https://hackage.haskell.org/package/base-4.16.2.0/docs/Control-Concurrent-MVar.html), or [TVar](https://hackage.haskell.org/package/stm-2.5.0.2/docs/Control-Concurrent-STM-TVar.html) or to implement the [Producer/Consumer pattern](https://www.baeldung.com/java-producer-consumer-problem) seen ubiquitously in Java concurrency?
1. Why, when I start out using TaskGroup and `async let` in my designs do I eventually find myself ending up discarding them and using their unstructured counterparts?
1. Why is that whenever I ask someone: "Do you use TaskGroup or `async let` and if so, how?", they (to date) have invariably responded, "I don't but I'm sure that there are many other people who do because they are really great."?
1. Why is it that in Structured Concurrency, Task lifetimes must align with the lifetime of the Task that created them, but that all of my other objects which are in a parent-child relationship have no such lifetime restriction and can instead be shared or have ownership transferred and, in the end, just be managed by ARC?
1. Why is that alone of all the objects I write, ARC does not seem to apply to Task?
1. What are the differences between `actor` and `AtomicReference` (from swift-atomics) and when would I use one over the other?
1. In what cases would I use an AsyncStream to manage mutable state and in what cases would I use an `actor`?
1. Why, when I start out using actors in my design do I always end up using an AsyncStream or an AtomicReference instead?
1. Are there differences between what we mean when we refer to Structured Concurrency and what we mean when we refer to Functional Concurrency and precisely what would those differences be?
   
These questions have been nagging at me since early 2021 as Swift Concurrency was introduced.  Developing this repository has helped me answer them to my own satisfaction, though of course, YMMV.  My answers to all of these questions are explored in the Playgrounds section of this repository. The major design choices made in FreeCombine should all be plain there.


### Protocol-free

### Race-free

### Leak-free

In essence, my answers to the questions above lead to organizing concurrent Swift applications along different lines than those promulgated by [Swift Evolution Proposal 304](https://github.com/apple/swift-evolution/blob/main/proposals/0304-structured-concurrency.md#proposed-solution).  SE-304 advocates that every task must not outlive the task that created it.  "Not outlive" in this context means that every task should either complete or be in the cancelled state before its creator completes.  

FreeCombine changes that restriction to be: every task must "owned" and may not outlive its owner(s).  If that restriction reminds you of ARC, that's because that's exactly what it is.  Instead of Structure Concurrency 
   
### Lock-free

## Additional notes to be organized in the future
   
### Functional Requirements

In November of 2021 [Phillipe Hausler observed](https://forums.swift.org/t/should-asyncsequence-replace-combine-in-the-future-or-should-they-coexist/53370/10) that there were several things that needed to be done to bring Combine functionality into the new world of Swift Concurrency. The list provided there was added to the requirements and the following are currently in the library:

1. Combinators
1.. Distributors (which I have termed Decombinators)
1. Temporal Transformation
1. Failure Transformation
1. Getting the first result from N running tasks

### Design Philosophy

I've taught Combine several times now and invariably 3 questions come up:

1. Why does every function on a Publisher return a different type?
1. Why does chaining of Publisher functions produce incomprehensible types?
1. Why do the required functions for a Publisher and Subscriber all say `receive`?

I believe that these are reasonable questions and this project attempts to deal with all three.

Additionally, there are similar questions with EventLoopFuture and EventLoopPromise in NIO.

1. Why is Future a class and not a struct?
1. Why can't NIO just use Concurrency like other Swift libraries?
1. Are there other use cases that I should be worrying about where I can't use Concurrency?

### Salient features

1. "Small things that compose"
1. Implement all operations supported by Combine, but some require modification
1. Uses "imprecise" errors throughout in the manner of Swift NIO.
1. Tasks and Continuations can _always_ fail due to cancellation so no Failure type on Continuations
1. Principled handling of cancellation throughout 
1. Futures _AND_ Streams, chocolate _AND_ peanut butter
1. No dependency on Foundation
1. Finally and very importantly, ownership of Tasks/Cancellables can be transferred or even shared.

### On Deprotocolization

The answer to question 1 about Combine, on why every function returns a different type, essentially comes down to Combine having `Publisher` be an existential type (aka a protocol) rather than a concrete generic type. Here's an example of what I'm talking about:

![Combine Return Types](Images/CombineReturnTypes.png)

Here's a challenge I give my students. The map functions on Array and Optional look like this:

```
 (Array<A>) ->    (_ f: (A) -> B) -> Array<B>
 (Optional<A>) -> (_ f: (A) -> B) -> Optional<B>
```

It looks as if we should be able to write a protocol `Mappable` which would accomodate both cases and which Array and Optional could conform to. Turns out that you can't for reasons that are explained deeply by Elviro Rocca [here](https://broomburgo.github.io/fun-ios/post/why-monads/). The heading: `Can we go higher?` about 2/3 of the way down discusses why you can't write that protocol.

If we insist on the use of protocols for Combine, the only real alternative is to provide a concrete generic type as the return type for every function. This is precisely the problem that Joe Groff describes in his famous [April 2019 post on opaque return types](https://forums.swift.org/t/improving-the-ui-of-generics/22814#heading--limits-of-existentials).

Following onto the ideas in those posts, [Holly Borla in SE-335](https://github.com/apple/swift-evolution/blob/main/proposals/0335-existential-any.md#introduction) makes a very compelling case for why we avoid should protocols in libraries like Combine. Here's the money quote:

> Existential types in Swift have an extremely lightweight spelling: a plain protocol name in type context means an existential type. Over the years, this has risen to the level of active harm by causing confusion, leading programmers down the wrong path that often requires them to re-write code once they hit a fundamental limitation of value-level abstraction.

In my opinion, what SE-335 is saying applies to Combine (and frankly to AsyncSequence in the standard library). The question is: how do we _NOT_ use existentials in a library like Combine. And the answer is to use generics instead. In the next playground we derive a generic-only version of Combine from the required Combine protocols 

### Flow of Control

1. Subscription provides 1 demand
1. Additional values are only sent when previous call returns .more
1. An infinite number of values can be sent
1. Completion can occur in the following ways:
    * Returning .done means that no more values will be sent (reactive completion).
    * Throwing an error means that no more values will be sent
    * Sending .completion(.finished|.cancelled|.failure(Error)) means that the value returned is ignored (proactive)
    * External cancellation causes .completion(.cancelled) to be sent as the next demanded value (external)

### Todo

1. ~~Implement leak prevention on UnsafeContinuation, Task, and AsyncStream.Continuation~~
1. ~~maybe add an additional repo (FreeCombineDispatch) that depends on libdispatch to get delay, debounce, throttle~~
1. Revamp and simplify StateThread to be exactly a concurrency aware version of TCA's store
1. Add support for Promise/Future
1. Add a repo which implements asyncPublishers for everything in Foundation that currently has a `publisher`
1. ~~fully implement all Combine operators~~
1. Add a Buffer publisher/operator to reintroduce a push model via an independent source of demand upstream
1. Create a `Scheduler`-like version of `sleep` which allows us to control clock advance.
1. Get to 100% test coverage
1. Document this at the level of writing a book in the form of playgrounds
