//: [Previous](@previous)

// Quick review
// We are going to make an infix version of our
// compose function and another function called apply
// Compose will have the higher precedence
precedencegroup ApplicationPrecedence {
  associativity: left
  higherThan: AssignmentPrecedence
}
precedencegroup CompositionPrecedence {
  associativity: right
  higherThan: ApplicationPrecedence
  lowerThan: MultiplicationPrecedence, AdditionPrecedence
}

// Here are the two operators we will use
infix operator >>> : CompositionPrecedence  // Composition
infix operator |>  : ApplicationPrecedence  // Application

// Here is the compose function we have played with many times
public func compose<A, B, C>(
    _ f: @escaping (A) -> B,
    _ g: @escaping (B) -> C
) -> (A) -> C {
    { a in g(f(a)) }
}

// Here's the compose function expressed using the infix operator we defined above.
// Doing this makes it easier to read (in many circumstances)
// This EXACTLY the same as `compose` just named to be an operation in infix notation.
public func >>><A, B, C>(
    _ f: @escaping (A) -> B,
    _ g: @escaping (B) -> C
) -> (A) -> C {
    { a in g(f(a)) }
}

// Here are three functions that compose together that we will play with
// for the rest of this playground.  What these functions do is really
// immaterial.  What is important is that they "compose".
func doubler(_ value: Int) -> Double { .init(value * 2) }
func toString(_ value: Double) -> String { "\(value)" }
func encloseInSpaces(_ value: String) -> String { "   \(value)   " }

// what does it mean to say that functions "compose"
// It means we can do the following
encloseInSpaces(toString(doubler(14)))

// Note that functions have type and it is the type that allows them to compose
type(of: doubler)

// I can compose (Int)    -> Double    with:
//               (Double) -> String    with:
//               (String) -> String
// To yield a function (Int) -> String
// In doing so, I have "erased" the Double and the first String

// I can take _any_ function of one variable and make it
// a computed var on the type of the variable
// This is possible because computed vars are really functions themselves
extension Double {
    // underneath this is a function (Double) -> String
    var toString: String { "\(self)" }
}
extension String {
    // underneath this is a function (String) -> String
    var encloseInSpaces: String { "   \(self)   " }
}

extension Int {
    // And this is a function (Int) -> Double
    var doubler: Double { .init(self * 2) }
}

// Importantly, _EVERYTHING_ you think of as a `method` on an object
// is, in fact, a curried function
extension Int {
    // (Int) -> () -> Double
    func yetAnotherDoubler() -> Double { .init(self * 2) }

    // (Int) -> (Double) -> Double
    func add(someDouble: Double) -> Double { Double(self) + someDouble }

    // (Int) -> (Int, Double) -> Double
    func multiply(by anInt: Int, andAdd aDouble: Double) -> Double { Double(self * anInt) + aDouble }
}

extension Int {
    static func anotherDoubler(_ anInt: Int) -> Double { .init(anInt * 2) }
}

// Proof about the function types stated above
type(of: Int.anotherDoubler)    // (Int) -> Double
type(of: Int.yetAnotherDoubler) // (Int) -> () -> Double
type(of: Int.add)               // (Int) -> (Double) -> Double
type(of: Int.multiply)          // (Int) -> (Int, Double) -> Double

func yetAnotherDoubler(_ `self`: Int) -> () -> Double {
    { .init(`self` * 2) }
}
type(of: yetAnotherDoubler) // (Int) -> () -> Double

14.doubler
14.yetAnotherDoubler()

// NB The compiler lies to us about computed vars, it won't tell us the type like
// it will functions
type(of: \Int.doubler)

// These statements are exactly equivalent, however
doubler(14)
14.doubler

// Reminder I can _always_ rearrange arguments to a function
func flip<A, B, C>(
    _ f: @escaping (A, B) -> C
) -> (B, A) -> C {
    { b, a in f(a,b) }
}

func flip<A, B, C>(
    _ f: @escaping (A) -> (B) -> C
) -> (B) -> (A) -> C {
    { b in { a in f(a)(b) } }
}

func flip<A, C>(
    _ f: @escaping (A) -> () -> C
) -> () -> (A) -> C {
    { { a in f(a)() } }
}

let flipYetAnother = flip(yetAnotherDoubler)()
flipYetAnother(14)

// Infix form
// `+` is a function, just in "infix" form
14 + 13

// Now lets use our compose operator (>>>) that we defined above
// Note how all of these give the same answer
encloseInSpaces(toString(doubler(14)))
let composedDoubleString = compose(doubler, compose(toString, encloseInSpaces))
composedDoubleString(14)
let doubleString = doubler >>> toString >>> encloseInSpaces
doubleString(14)

// inline the compositions "by hand"
let toStringExplicit = { innerInt in toString(doubler(innerInt) ) }
let encloseInSpacesExplicit = { outerInt in encloseInSpaces(toStringExplicit(outerInt) ) }
// lambda calculus form
let doubleStringExplicit = { outerInt in encloseInSpaces({ innerInt in toString(doubler(innerInt)) }(outerInt) ) }
doubleStringExplicit(14)

let value = 14
doubleString(value)
doubleStringExplicit(value)
(doubler >>> toString >>> encloseInSpaces)(value)
doubleStringExplicit(14)

// Now lets introduce an `apply` function as reversed invocation
// Note: when marked with @inlinable the compiler reduce apply(a, f) to precisely f(a)
func apply<A, R>(
    _ a: A,
    _ f: (A) -> R
) -> R {
    f(a)
}

            apply(14,      doubler)
      apply(apply(14,      doubler),         toString)
apply(apply(apply(14,      doubler),         toString),         encloseInSpaces)
apply(apply(apply(14, \Int.doubler), \Double.toString), \String.encloseInSpaces)
apply(apply(apply(14,    \.doubler),       \.toString),       \.encloseInSpaces)

apply(14, doubleString)

// And of course we can do apply in infix notation as well
// Note that this is _exactly_ the apply function, just in `infix` form
public func |><A, R>(
    _ a: A,
    _ f: (A) -> R
) -> R {
    f(a)
}

// Given the above, all of these are EXACTLY the same thing
// we're just sprinkling on some "syntactic sugar"
apply(14, doubler)
14 |> doubler
14 |> \Int.doubler
14 |> \.doubler

// if we used the infix form of apply, these would be the same as:
14.doubler
doubler(14)

// Now lets compare and contrast apply and compose
// reminder, this is composition in what is known as the "direct" style
(doubler >>> toString >>> encloseInSpaces)(14)        // Direct Style

// each of these is different, but all yield the exact same result
// Now we see why the use of algebra style infix notation is SO very
// important.  Clean notation allows to concisely think about manipulation
// of functions.
14 |>   doubler >>>   toString >>>   encloseInSpaces  // direct style
14 |> \.doubler >>> \.toString >>> \.encloseInSpaces  // direct style
14 |>   doubler |>    toString >>>   encloseInSpaces  // mixed style
14 |>   doubler >>>   toString |>    encloseInSpaces  // mixed style
14 |>   doubler |>    toString |>    encloseInSpaces  // Continuation Passing Style
14 |> \.doubler |>  \.toString |>  \.encloseInSpaces  // Continuation Passing Style
14     .doubler      .toString      .encloseInSpaces  // OOP native style

// writing the above out long hand..

// The last two (when inlined) reduce as follows:
apply(apply(apply(14, doubler), toString), encloseInSpaces)
encloseInSpaces(apply(apply(14, doubler), toString))
encloseInSpaces(toString(apply(14, doubler)))
encloseInSpaces(toString(doubler(14)))
// i.e. we come right back to composition

// This one is in lambda calculus form
//14 |> doubler >>> toString >>> encloseInSpaces  // direct style
compose(doubler, compose(toString, encloseInSpaces))(14)
({ outerInt in encloseInSpaces({ innerInt in toString(doubler(innerInt)) }(outerInt) ) })(14)

// The compiler can also optimize _THAT_ to exactly:
encloseInSpaces(toString(doubler(14)))

// Interestingly, underneath, the compiler _actually_ uses
// Single Static Assignment (SSA) form in the final output
// or you can think of it as what the compiler would put out:
let a = 14 |> doubler          // or doubler(14)
let b = a  |> toString         // or toString(a)
let c = b  |> encloseInSpaces  // or encloseInSpaces(b)

// In summary, all of these _do_ the same thing
// but _are not_ the same thing
(doubler >>> toString >>> encloseInSpaces)(14)  // Direct Style
compose(doubler, compose(toString, encloseInSpaces))(14)
14 |> doubler >>> toString >>> encloseInSpaces  // mixed style
apply(14, compose(doubler, compose(toString, encloseInSpaces)))

14 |> doubler |>  toString >>> encloseInSpaces  // mixed style
apply(apply(14, doubler), compose(toString, encloseInSpaces))

14 |> doubler >>> toString |>  encloseInSpaces  // mixed style
apply(apply(14, compose(doubler, toString)), encloseInSpaces)

14 |> doubler |>  toString |>  encloseInSpaces  // Continuation Passing Style
apply(apply(apply(14, doubler), toString), encloseInSpaces)

// Looking closely at that last one we discover that application
// and the continuation passing style are something that we
// already knew as the Object-Oriented style
14 |> doubler |>  toString |>  encloseInSpaces  // Continuation Passing Style
14   .doubler    .toString    .encloseInSpaces  // Object-Oriented Style
// [[[14 doubler] toString]    encloseInSpaces] // ObjC syntax
// encloseInSpaces(toString(doubler(14)))

// OO with immutable value types is exactly equivalent to Continuation Passing Style (CPS)

// Now, what does it look like if we _curry_
// our apply function
func curriedApply<A, R>(
    _ a: A
) -> (@escaping (A) -> R) -> R {
    { f in f(a) }
}
// Note what is returned from curriedApply:
// ((A) -> B) -> B
// This is what is called in Haskell and other FP languages, a Continuation

// Proof that apply and curriedApply are exactly the same thing.
       apply(       apply(       apply(14, doubler), toString), encloseInSpaces)
curriedApply(curriedApply(curriedApply(14)(doubler))(toString))(encloseInSpaces)

// BTW, it is instructive to curry compose as well, bc we will be coming
// back to this.
public func curriedCompose<A, B, C>(
    _ f: @escaping (A) -> B
) -> (@escaping (B) -> C) -> (A) -> C {
    { g in { a in g(f(a)) } }
}

// Proof that compose and curriedCompose are exactly the same thing.
compose       (doubler,        compose(toString, encloseInSpaces))(14)
curriedCompose(doubler)(curriedCompose(toString)(encloseInSpaces))(14)

// Again, note that these all give EXACTLY IDENTICAL results
// And that translating from one form to another ia a completely
// mechanical process
       apply(       apply(       apply(14, doubler), toString), encloseInSpaces)
curriedApply(curriedApply(curriedApply(14)(doubler))(toString))(encloseInSpaces)

// Note that apply nests left, compose nests right
       compose(doubler,        compose(toString, encloseInSpaces))(14)
curriedCompose(doubler)(curriedCompose(toString)(encloseInSpaces))(14)

// Also note that we are able to do this to ANY function that is in
// the standard one-argument form.  And that it is only slightly
// more complicated in the multi-argument form
// And that we can do this only because we have generics.  Generics
// are absolutely critical to this ability to compose.

// Interesting side-note: suppose we _flip_ the arguments to apply

// Flipped form of apply (here called invoke) turns out to be the natively supported invocation form

// reminder this is the apply func from above:
//public func apply<A, R>(
//    _ a: A,
//    _ f: (A) -> R
//) -> R {
//    f(a)
//}

// Flipping that yields:
public func invoke<A, R>(
    _ f: (A) -> R,
    _ a: A
) -> R {
    f(a)
}
// Which is just the same as f(a)

// If we then _curry_ invoke
func curriedInvoke<A, R>(
    _ f: @escaping (A) -> R
) -> (A) -> R {
    f
}
// curried invoke just turns out to be the identity
// function operating on the supplied funcion.  Making it @inlinable allows the
// compiler to, in fact remove it and just use the
// native function invocation operation that is built in
// to the language

// The Big Leap
// Lifting curriedApply from a structural type, i.e. just a function
// to be a nominal type, i.e. a struct with a function as it's only member.

// Up to this point we've just been playing with Swift's
// syntax for functions, rearranging things in various ways
// and showing that different rearrangements produce identical
// results.  NOW we make real use of what generics give us

// Notes:
// 1. trailing function from curriedApply becomes the let
// 2. there are TWO inits: the default init + the init that takes the _leading_ value from curriedApply
// 3. We add a callAsFunction to denote that this is in fact a lifted function
// 4. the let is exactly the shape of the Haskell Continuation monad right down to the A and the R

public struct Continuation<A, R> {
    public let sink: (@escaping (A) -> R) -> R

    public init(sink: @escaping (@escaping (A) -> R) -> R) {
        self.sink = sink
    }
    public init(_ a: A) {
        self = .init { downstream in
            downstream(a)
        }
    }
    public func callAsFunction(_ f: @escaping (A) -> R) -> R {
        sink(f)
    }
}

// If this is correct, we should be able to
// implement curriedApply using the new type
// and have it just work..
func continuationApply<A, R>(
    _ a: A
) -> (@escaping (A) -> R) -> R {
    Continuation(a).sink // .sink here is exactly of type: (@escaping (A) -> R) -> R
}

// Proof that apply, curriedApply, continuationApply and Continuation are the exact same thing:
apply            (apply            (apply            (14, doubler), toString), encloseInSpaces)
curriedApply     (curriedApply     (curriedApply     (14)(doubler))(toString))(encloseInSpaces)
continuationApply(continuationApply(continuationApply(14)(doubler))(toString))(encloseInSpaces)
Continuation     (Continuation     (Continuation     (14)(doubler))(toString))(encloseInSpaces)
// And since we have already shown that apply is equivalent to the OOP style, we now have
// by transitivity that OOP is just programming in the Continuation Passing Style.

// And again, with suitable inlining, the compiler can reduce every one of these to:
encloseInSpaces(toString(doubler(14)))

//: [Next](@next)
