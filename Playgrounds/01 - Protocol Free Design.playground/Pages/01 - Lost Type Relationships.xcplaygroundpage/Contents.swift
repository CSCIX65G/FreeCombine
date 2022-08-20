//: [Previous](@previous)

/*:
 ## The "Crusty" Talk

 In 2015, one year after the introduction of Swift, Dave Abrahams gave the famous "Crusty" talk at WWDC15.  Remember, this was shortly after the release of Swift 1.1

![The Crusty Talk](POP-1.pdf)

 ## Classes are Awesome

 In that talk, Dave talks about the really useful stuff that we have gotten from Classes in ObjC and, because Swift interoperates with ObjectiveC, from Swift.

 ![Classes are Awesome](ClassesAreAwesome.pdf)

Then Dave points out that in fact, its not just `classes` that can provide these features.  You can get the same features from value types, i.e. structs and enums.

 ## Types are Awesome

 ![Types are Awesome](TypesAreAwesome.pdf)

 But there's something really odd here. If you look up Object-Oriented Programming, you find that two of the  distinguishing features of the object-oriented style are: encapsulation and polymorphism.  And encapsulation is right there at the top of Dave's list of awesomeness.  Yet polymorphism completely fails to make the cut.  What gives?

 Dave is making the point in this presentation that classes provide a particular form of polymorphism known as inheritance and without giving too much of the rest of the presentation away, I can say that he will proceed to argue for using another form of polymorphism exclusively. Specifically that form is protocols (also known as "existentials") and the reasons for using it exclusively will be discussed below.

 But this entire argument has something else very odd about it as well.  Swift supports _three_ forms of polymorphism, not just two. And the "Crusty Talk" remains completely silent on the third.  John McCall is quite explicit in [this Swift Evolution post](https://forums.swift.org/t/pitch-2-light-weight-same-type-requirement-syntax/55081/153) about the 3 types of polymorephism (which he refers to as "generalization"):

 > Well, Swift has three ways to generalize over different types of values. One of them is subclassing, and that's inherently a limited form of generalization: it only works when you've got classes with a common superclass. The other two are generics and existential types.

 Note the almost off-handed dismissal of inheritance there.  He explicitly states that inheritance is a very limited form of polymorphism and then _never mentions it again for the rest of his post_.

 Ok, so its at this point in Dave's presentation that he gives his famous "3 Beefs".  We'll deal with those in just a minute, but first I want to introduce what I call:

 ## Beef Zero

 Classes are a particular storage representation of what in type theory are referred to as _"product"_ types. In Swift, the product type with "value semantics" is `struct`, the product type with "reference semantics" is class.  Value types are types where the storage for instances of the type is owned by something else, frequently the stack. Reference types are types where the storage is owned by reference, generally to a location in the heap.  It is this referential storage which enables classes to implement inheritance as a technique.

 So classes and structs are deeply related.  But... the manner in which a type is stored is orthogonal to it semantics as a Product type.  You can store a product type by value or by reference.  Classes are the reference product type, structs are the value product type.

 So if they're both product types and the difference is that only reference storage semantics can do inheritance, why not just use the reference storage mechanism and get inheritance "for free" to use or not use as the programmer sees fit.  Well...

 Because, inheritance, as a feature of reference product types, forces us to give up 2 really valuable features:

 1. isolation and atomicity and
 1. the expressiveness of enums (Sum types) as objects.

 NB We can get some of this back by using classes as generic reference types.

 ## The 3 Beefs

 But in the Crusty talk, Dave laid out three problems beyond sacrificing value semantics.

![The Three Beefs](POP-2.pdf)

 ## Concurrency

 Actors don't do inheritance.
![The Crusty Talk](POP-3.pdf)

 ## Single Inheritance

 If you have to derive from someone else's class to get behavior, you have a problem.
![The Crusty Talk](POP-4.pdf)

 ## Lost Type Relationships

 Classes inherently can provide only coarse-grained type relationships
![The Crusty Talk](POP-5.pdf)

 ## The Tell-tale Sign of a Lost Type Relationship

 If you use `as!`, `as?`, `isKindOf:`, `isMemberOf:` you have encountered the inability of inheritance to model fine-grained relationships between types.

![The Crusty Talk](POP-6.pdf)

 ## Protocol Oriented Programming
![The Crusty Talk](POP-7.pdf)

 ## The Challenge: Prove It!
![The Crusty Talk](POP-8.pdf)

 ## Protocols have problems too

 The point about lost type relationships also applies to protocols.

 From [Joe Groff's 2019 post](https://forums.swift.org/t/improving-the-ui-of-generics/22814#heading--limits-of-existentials) introducing opaque result types:

 > Because existentials eliminate the type-level distinction between different values of the type, they cannot maintain type relationships between independent existential values.

 Hmm.. I could have sworn that one of Dave's points in 2015 was that failure to maintain type relationships between independent values was a major reason _NOT_ to use a polymorphism technique.  _(checks notes)_ Yep.  That's what he was saying.  Seems like that should also apply to protocols.

 In fact... In 2021, Holly Borla, writing in [Swift Evolution Proposal 335](https://github.com/apple/swift-evolution/blob/main/proposals/0335-existential-any.md#introduction) explicitly quotes Joe's post and says:

 > Existential types in Swift have an extremely lightweight spelling: a plain protocol name in type context means an existential type. Over the years, this has risen to the level of active harm by causing confusion, leading programmers down the wrong path that often requires them to re-write code once they hit a fundamental limitation of value-level abstraction.

 The problem here is that she doesn't really give us any simple rules for how we can tell that we have hit the "fundamental limitations".  I'd like to propose one:

 ## The Tell-tale Sign: Protocol Edition
![Return Types in Combine](CombineReturnTypes.png)

 ## Demand only comes in More and All
![Demand](Demand.png)

*/

//: [Next](@next)
