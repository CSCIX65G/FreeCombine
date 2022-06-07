[edit](https://github.com/CSCIX65G/FreeCombine/edit/gh-pages/README.md)

# FreeCombine

## Combine. Only free. And concurrent.

- Protocol-free.
- Race-free.

  - Yield-free.
  - Sleep-free.

- Leak-free.

  - Unbounded queue-free.

- Lock-free.
- Dependency-free.

## Salient features

1. "Small things that compose"
2. Implement all operations supported by Combine, but some require modification
3. Uses "imprecise" errors throughout in the manner of Swift concurrency
4. Futures _AND_ Streams

## Todo

1. maybe add an additional repo (FreeCombineDispatch) that depends on libdispatch to get delay, debounce, throttle
2. revamp StateThread to be exactly a concurrency aware version of TCA's store
3. Add support for Promise/Future
4. Add a repo which implements asyncPublishers for everything in Foundation that currently has a `publisher`
5. fully implement all Combine operators
6. Add a Buffer publisher/operator to reintroduce a push model via an independent source of demand upstream
7. Get to 100% test coverage
8. Document this at the level of writing a book in the form of playgrounds

  ## Introduction

  For a long time I've been exploring the idea of what Apple's Swift Combine framework would look like without using protocols. The advent of Concurrency support in Swift 5.5 provided an impetus to complete that exploration. This repository represents the current state of that effort and consists of material that I intend to incorporate into classes I teach on iOS development at [Harvard](https://courses.dce.harvard.edu/?details&srcdb=202203&crn=33540) and at [Tufts](https://www.cs.tufts.edu/t/courses/description/fall2021/CS/151-02).

  Ideally, this material would become the core of an expanded course on Functional Concurrent Programming using Swift, but that course is still fairly far off.

  ### Functional Requirements

  In November of 2021 [Phillipe Hausler observed](https://forums.swift.org/t/should-asyncsequence-replace-combine-in-the-future-or-should-they-coexist/53370/10) that there were several things that needed to be done to bring Combine functionality into the new world of Swift Concurrency. The list provided there was added to the requirements and the following are currently in the library:

  1. Combinators
  2. Distributors
  3. Temporal Transformation
  4. Failure Transformation
  5. Getting the first result from N running tasks

  ## Design Philosophy

  I've taught Combine several times now and invariably 3 questions come up:

  1. Why does every function on a Publisher return a different type?
  2. Why does chaining of Publisher functions produce incomprehensible types?
  3. Why do the required functions for a Publisher and Subscriber all say `receive`?

  I believe that these are reasonable questions and this project attempts to deal with all three.

  Additionally, there are similar questions with EventLoopFuture and EventLoopPromise in NIO.

  1. Why is Future a class and Promise a struct?
  2. Why can't NIO just use Concurrency like other Swift apps?
  3. Are there other use cases that I should be worrying about where I can't use Concurrency?

  ### On Deprotocolization

The answer to question 1 on why every function returns a different type essentially comes down to the use of having Publisher be an existential type (aka a protocol) rather than a plan generic type. Here's an example of what I'm talking about:

![Combine Return Types](Playgrounds/01\ -\ Protocol\ Free Design.playground/Resources/CombineReturnTypes.png)

Here's a challenge I give my students. Map on Array is a function that looks like this:

```
 (Array<A>) ->    (_ f: (A) -> B) -> Array<B>
```

Map on Optional looks like this:

```
 (Optional<A>) -> (_ f: (A) -> B) -> Optional<B>
```

It looks as if we should be able to write a protocol `Mappable` which would accomodate both cases and which Array and Optional could conform to. Turns out that you can't for reasons that are explained deeply by Elviro Rocca [here](https://broomburgo.github.io/fun-ios/post/why-monads/). The heading: `Can we go higher?` about 2/3 of the way down discusses why you can't write that protocol.

If we insist on the use of protocols for Combine, the only real alternative is to provide a concrete generic type as the return type for every function. This is precisely the problem that Joe Groff describes in his famous [April 2019 post on opaque return types](https://forums.swift.org/t/improving-the-ui-of-generics/22814#heading--limits-of-existentials).

Following onto the ideas in those posts, [Holly Borla in SE-335](https://github.com/apple/swift-evolution/blob/main/proposals/0335-existential-any.md#introduction) makes a very compelling case for why we avoid should protocols in libraries like Combine. Here's the money quote:

```
Existential types in Swift have an extremely lightweight spelling: a plain protocol name in type context means an existential type. Over the years, this has risen to the level of active harm by causing confusion, leading programmers down the wrong path that often requires them to re-write code once they hit a fundamental limitation of value-level abstraction.
```

In my opinion, what SE-335 is saying applies to Combine (and frankly to AsyncSequence in the standard library). The question is: how do we _NOT_ use existentials in a library like Combine. And the answer is to use generics instead. In the next playground we derive a generic-only version of Combine from the required Combine protocols */
