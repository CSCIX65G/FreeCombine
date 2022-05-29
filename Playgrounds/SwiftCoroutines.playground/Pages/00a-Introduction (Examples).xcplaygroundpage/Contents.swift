
/*:
 # Introduction

 For a long time I've been exploring the idea of what Apple's Swift Combine
 framework would look like without using protocols.  The advent of Concurrency support
 in Swift 5.5 provided an impetus to complete that exploration.  This repository represents
 the current state of that effort and consists of material that I intend to incorporate into classes
 I teach on iOS development at [Harvard](https://courses.dce.harvard.edu/?details&srcdb=202203&crn=33540)
 and at [Tufts](https://www.cs.tufts.edu/t/courses/description/fall2021/CS/151-02).

 Ideally, this material
 would become the core of an expanded course on Functional Concurrent Programming using Swift, but that
 course is still fairly far off.

 ## Introduction to Combine:

 Here's a silly example of using combine to manipulate streams of data of various types.

 */
import Combine

let subject1 = Combine.PassthroughSubject<Int, Error>()
let subject2 = Combine.PassthroughSubject<String, Error>()

let seq1 = "abcdefghijklmnopqrstuvwxyz".publisher
let seq2 = (1 ... 100).publisher

let z1 = seq1.zip(seq2)
let m1 = subject1
    .map(String.init)
    .mapError { _ in fatalError() }
    .merge(with: subject2)
    .replaceError(with: "")

let z2 = z1
    .map { left, right in String(left) + String(right) }

let m2 = z2.merge(with: m1)
let cancellable = m2.sink { value in
    print(value)
}

subject1.send(14)
subject2.send("hello, combined world!")
subject1.send(completion: .finished)
subject2.send(completion: .finished)

print("=========================================================")

/*:
 Here's the same example done using FreeCombine:
 */
import FreeCombine
import _Concurrency

Task {
    let fsubject1 = await FreeCombine.PassthroughSubject(Int.self)
    let fsubject2 = await FreeCombine.PassthroughSubject(String.self)

    let fseq1 = "abcdefghijklmnopqrstuvwxyz".asyncPublisher
    let fseq2 = (1 ... 100).asyncPublisher

    let fz1 = fseq1.zip(fseq2)
    let fm1 = fsubject1.publisher()
        .map(String.init)
        .mapError { _ in fatalError() }
        .merge(with: fsubject2.publisher())
        .replaceError(with: "")

    let fz2 = fz1
        .map { left, right in String(left) + String(right) }

    let fm2 = fz2.merge(with: fm1)
    let fcancellable = await fm2.sink { value in
        guard case let .value(value) = value else { return .more }
        print(value)
        return .more
    }

    try await fsubject1.send(14)
    try await fsubject2.send("hello, combined world!")
    try await fsubject1.finish()
    try await fsubject2.finish()
    let finalDemand = try await fcancellable.task.value
    print(finalDemand)
}

/*:
 ## Project Requirements

 ### Design Requirements/Differences from Combine
 This project differs from Apple's Combine in the following ways

 1. No use of protocols
 2. No race conditions
 3. No locks
 4. Eager type erasure
 5. Use of concurrent functions throughout
 6. Incorporation of an improved concept of Promise and Future, based on the design of Swift NIO's EventLoopFuture (ELF) and EventLoopPromise (ELP)

 The rationale for these requirements and their implications are explored in detail below and in following playgrounds.

 ### Usage Requirements
 Additionally, the following requirements for this project have been set:

 1. No dependencies are allowed, except the Swift Std Library.  This also means no FoundationKit usage is allowed.
 2. Except at boundaries specified by the use of Subjects, all publishing is demand-pull, rather than supply-push. No internal queueing is allowed within Publishers
 3. Whilst publishing of values is async, all setup, cancellation and sending via Subjects is synchronous.
 4. A full Swift Concurrency replacement for NIO's EventLoopFuture and EventLoopPromise is provided which includes ELP's anti-leak guarantees

 ### Functional Requirements
 In November of 2021 [Phillipe Hausler observed](https://forums.swift.org/t/should-asyncsequence-replace-combine-in-the-future-or-should-they-coexist/53370/10) that there were several things that needed to be done to bring Combine functionality into the new world of Swift Concurrency.  The list provided there was added to the requirements and the following are currently in the library:

 1. Combinators
 2. Distributors
 3. Temporal Transformation
 4. Failure Transformation
 5. Getting the first result from N running tasks

 ## Design Philosophy

 I've taught Combine several times now and invariably 3 questions come up:

 1. Why does every function on a Publisher return a different type?
 2. Why do the required functions for a Publisher and Subscriber all say `receive`?
 3. Why does chaining of Publisher functions produce incomprehensible types?

 I believe that these are reasonable questions and this project attempts to deal with all three

 ### On Deprotocolization

The answer to question 1 on why every function returns a different type essentially comes down to the use of having Publisher be an existential type (aka a protocol) rather than a plan generic type.  Here's an example of what I'm talking about:

 ![Combine Return Types](CombineReturnTypes.png)

 Here's a challenge I give my students.  Map on Array is a function that looks like this:
 ```
 (Array<A>) ->    (_ f: (A) -> B) -> Array<B>
 ```
 Map on Optional looks like this:
 ```
 (Optional<A>) -> (_ f: (A) -> B) -> Optional<B>
 ```
 It looks as if we should be able to write a protocol `Mappable` which would accomodate both cases
 and which Array and Optional could conform to.  Turns out that you can't for reasons that are explained
 deeply [here](https://broomburgo.github.io/fun-ios/post/why-monads/) by Elviro Rocca.  The heading: `Can we go higher?` about 2/3 of the way down discusses why you can't write that protocol.

 If we insist on the use of protocols for Combine, the only real alternative is to provide a concrete generic
 type as the return type for every function.  This is precisely the problem that Joe Groff describes in his famous [April 2019 post on opaque return types](https://forums.swift.org/t/improving-the-ui-of-generics/22814#heading--limits-of-existentials).

 Following onto the ideas in those posts, [Holly Borla in SE-335](https://github.com/apple/swift-evolution/blob/main/proposals/0335-existential-any.md#introduction)
 makes a very compelling case for why we avoid should protocols in libraries like Combine.  Here's the money quote:
```
Existential types in Swift have an extremely lightweight spelling: a plain protocol name in type context means an existential type. Over the years, this has risen to the level of active harm by causing confusion, leading programmers down the wrong path that often requires them to re-write code once they hit a fundamental limitation of value-level abstraction.
 ```
In my opinion, what SE-335 is saying applies to Combine (and frankly to AsyncSequence in the standard library).  The question is: how do we _NOT_ use existentials in a library like Combine.  And the answer is to use generics instead.  In the next playground we derive a generic-only version of Combine from the required Combine protocols
 */
//: [Next](@next)
