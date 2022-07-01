[edit](https://github.com/CSCIX65G/FreeCombine/edit/gh-pages/README.md)

# FreeCombine

## Like Combine. Only free. And concurrent.

* Protocol-free.
  * No protocols, only concrete types
  * Eager type erasure
  * Continuation-passing style
* Race-free.
  * Yield-free.
  * Sleep-free.
  * Continuations are only created after upstream continuations are guaranteed to exist
* Leak-free.
  * Memory-bound Task resolution
  * Memory-bound Continuation resolution
  * Unbounded queue-free.
* Lock-free.
  * Queueing channel instead of locking channel
  * No use of `os_unfair_lock` or equivalent constructs in other operating system 
* Foundation-free.
  * depends only on Swift std lib (and swift-atomics)

Implies the following Do's and Dont's

Don'ts:
* No use of `protocol`
* No use of `TaskGroup` or `async let`
* No use of `AsyncSequence`
* No use of `swift-async-algorithms`

Sort of Don'ts:
* Use of `for await` only in StateTask
* Use of `Task.init` only in Cancellable
* Use of `[Checked|Unsafe]Continuation` only in Resumption
* Use of `AsyncStream.init` only in Channel

## Salient features

1. "Small things that compose"
1. Implement all operations supported by Combine, but some require modification
1. Uses "imprecise" errors throughout in the manner of Swift NIO.
1. Tasks and Continuations can _always_ fail due to cancellation
1. Principled handling of cancellation throughout 
1. Futures _AND_ Streams, chocolate _AND_ peanut butter

## Todo

1. ~~Implement leak prevention on UnsafeContinuation, Task, and AsyncStream.Continuation~~
1. maybe add an additional repo (FreeCombineDispatch) that depends on libdispatch to get delay, debounce, throttle
1. revamp StateThread to be exactly a concurrency aware version of TCA's store
1. Add support for Promise/Future
1. Add a repo which implements asyncPublishers for everything in Foundation that currently has a `publisher`
1. fully implement all Combine operators
1. Add a Buffer publisher/operator to reintroduce a push model via an independent source of demand upstream
1. Get to 100% test coverage
1. Document this at the level of writing a book in the form of playgrounds

  ## Introduction

  For a long time I've been exploring the idea of what Apple's Swift Combine framework would look like if written without using protocols. The advent of Concurrency support in Swift 5.5 provided an impetus to complete that exploration. This repository represents the current state of that effort and consists of material that I intend to incorporate into classes I teach on iOS development at [Harvard](https://courses.dce.harvard.edu/?details&srcdb=202203&crn=33540) and at [Tufts](https://www.cs.tufts.edu/t/courses/description/fall2021/CS/151-02).

  Ideally, this material would become the core of an expanded course on Functional Concurrent Programming using Swift, but that course is still fairly far off.  
  
  Secondarily, this repo is my own feeble attempt to answer the following questions: 
  
  1. Why does Swift's Structured Concurrency, not have the same set of primitives as Concurrent Haskell?
  1. Why is that whenever I ask someone: do you use TaskGroup or `async let`, they respond, I don't but I'm sure that there are other people who do?
  1. Are there differences between what we mean when we refer to Structured Concurrency and what we mean when we refer to Functional Concurrency and precisely what would those differences be?

  ### Functional Requirements

  In November of 2021 [Phillipe Hausler observed](https://forums.swift.org/t/should-asyncsequence-replace-combine-in-the-future-or-should-they-coexist/53370/10) that there were several things that needed to be done to bring Combine functionality into the new world of Swift Concurrency. The list provided there was added to the requirements and the following are currently in the library:

  1. Combinators
  2. Distributors (which I have termed Decombinators)
  3. Temporal Transformation
  4. Failure Transformation
  5. Getting the first result from N running tasks

  ## Design Philosophy

  I've taught Combine several times now and invariably 3 questions come up:

  1. Why does every function on a Publisher return a different type?
  1. Why does chaining of Publisher functions produce incomprehensible types?
  1. Why do the required functions for a Publisher and Subscriber all say `receive`?

  I believe that these are reasonable questions and this project attempts to deal with all three.

  Additionally, there are similar questions with EventLoopFuture and EventLoopPromise in NIO.

  1. Why is Future a class and not a struct?
  1. Why can't NIO just use Concurrency like other Swift libraries?
  1. Are there other use cases that I should be worrying about where I can't use Concurrency?

  ### On Deprotocolization

The answer to question 1 on why every function returns a different type essentially comes down to the use of having Publisher be an existential type (aka a protocol) rather than a plain generic type. Here's an example of what I'm talking about:

![Combine Return Types](Images/CombineReturnTypes.png)

Here's a challenge I give my students. The map functions on Array and Optional look like this:

```
 (Array<A>) ->    (_ f: (A) -> B) -> Array<B>
 (Optional<A>) -> (_ f: (A) -> B) -> Optional<B>
```

It looks as if we should be able to write a protocol `Mappable` which would accomodate both cases and which Array and Optional could conform to. Turns out that you can't for reasons that are explained deeply by Elviro Rocca [here](https://broomburgo.github.io/fun-ios/post/why-monads/). The heading: `Can we go higher?` about 2/3 of the way down discusses why you can't write that protocol.

If we insist on the use of protocols for Combine, the only real alternative is to provide a concrete generic type as the return type for every function. This is precisely the problem that Joe Groff describes in his famous [April 2019 post on opaque return types](https://forums.swift.org/t/improving-the-ui-of-generics/22814#heading--limits-of-existentials).

Following onto the ideas in those posts, [Holly Borla in SE-335](https://github.com/apple/swift-evolution/blob/main/proposals/0335-existential-any.md#introduction) makes a very compelling case for why we avoid should protocols in libraries like Combine. Here's the money quote:

```
Existential types in Swift have an extremely lightweight spelling: a plain protocol name in type context means an existential type. Over the years, this has risen to the level of active harm by causing confusion, leading programmers down the wrong path that often requires them to re-write code once they hit a fundamental limitation of value-level abstraction.
```

In my opinion, what SE-335 is saying applies to Combine (and frankly to AsyncSequence in the standard library). The question is: how do we _NOT_ use existentials in a library like Combine. And the answer is to use generics instead. In the next playground we derive a generic-only version of Combine from the required Combine protocols */
