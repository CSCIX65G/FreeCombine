//
//  FunctionProgramming.swift
//  FreeCombine
//
//  Created by Van Simmons on 4/11/20.
//  Copyright © 2020 ComputeCycles, LLC. All rights reserved.
//

/*:
 Handy functions for composition
 */
public func identity<T>(_ t: T) -> T { t }
public func void<T>(_ t: T) -> Void { }
public func cons<T>(_ t: T) -> () -> T { { t } }
public func unwrap<T>(_ t: T?) -> T { t! }

public func curry<A, B, C>(
    _ function: @escaping (A, B) -> C
) -> (A) -> (B) -> C {
    { (a: A) -> (B) -> C in
        { (b: B) -> C in
            function(a, b)
        }
    }
}

precedencegroup CompositionPrecedence {
  associativity: right
  higherThan: AssignmentPrecedence
  lowerThan: MultiplicationPrecedence, AdditionPrecedence
}

/*:
 Define an operator for the composition of two
 functions
 */
infix operator >>>: CompositionPrecedence
public func >>> <A, B, C>(
    _ f: @escaping (A) -> B,
    _ g: @escaping (B) -> C
) -> Func<A, C> {
    .init { (a: A) -> C in g(f(a)) }
}

public func >>> <A, B, C>(
    _ f: @escaping (A) -> B,
    _ g: Func<B, C>
) -> Func<A, C> {
    .init { (a: A) -> C in g(f(a)) }
}

func >>> <A, B, C, D: CallableAsFunction> (
    _ f: @escaping (A) -> B,
    _ g: D
) -> Func<A,C> where D.A == B, D.B == C {
    f >>> g.call
}

func >>> <A, B, C> (
    _ f: Func<A, B>,
    _ g: @escaping (B) -> C
) -> Func<A,C> {
    f.call >>> g
}

func >>> <A, B, C> (
    _ f: Func<A, B>,
    _ g: Func<B, C>
) -> Func<A,C> {
    f.call >>> g.call
}

func >>> <A, B, C, D: CallableAsFunction> (
    _ f: Func<A, B>,
    _ g: D
) -> Func<A,C> where D.A == B, D.B == C {
    f.call >>> g.call
}

func >>> <A, B, C, D: CallableAsFunction>(
    _ f: D,
    _ g: @escaping (B) -> C
) -> Func<A,C> where D.A == A, D.B == B {
    f.call >>> g
}

func >>> <A, B, C, D: CallableAsFunction>(
    _ f: D,
    _ g: Func<B, C>
) -> Func<A,C> where D.A == A, D.B == B {
    f.call >>> g.call
}

func >>> <A, B, C, D: CallableAsFunction, E: CallableAsFunction> (
    _ f: D,
    _ g: E
) -> Func<A,C> where D.A == A, D.B == B, E.A == B, E.B == C{
    f.call >>> g.call
}

/*:
 Define an operator for the application of a
 function to a value
 */
infix operator |>: CompositionPrecedence
public func |> <A, B> (
    a: A,
    f: (A) -> B
) -> B {
    f(a)
}

public func |> <A, B> (
    a: A,
    f: Func<A, B>
) -> B {
    f(a)
}

public func |> <A, B, C: CallableAsFunction> (
    a: A,
    f: C
) -> B where A == C.A, B == C.B {
    f(a)
}

public func |> <A: CallableAsFunction, B:CallableAsFunction> (
    a: A,
    f: (A) -> B
) -> B {
    f(a)
}

public func |> <A: CallableAsFunction, B:CallableAsFunction> (
    a: A,
    f: Func<A, B>
) -> B {
    f(a)
}

public func |> <A: CallableAsFunction, B:CallableAsFunction, C: CallableAsFunction> (
    a: A,
    f: B
) -> C where A == B.A, C == B.B {
    f(a)
}

public func |> <A, B, C, D> (
    a: @escaping (A) -> B,
    f: ((A) -> (B)) -> (C) -> D
) -> (C) -> D {
    f(a)
}

public func |> <A, B, C, D> (
    a: Func<A, B>,
    f: ((A) -> (B)) -> (C) -> D
) -> (C) -> D {
    f(a.call)
}

public func |> <A, B, C, D, E: CallableAsFunction> (
    a: E,
    f: ((A) -> (B)) -> (C) -> D
) -> (C) -> D where E.A == A, E.B == B {
    f(a.call)
}

public func |> <A, B, C, D> (
    a: Func<A, B>,
    f: ((A) -> B) -> (C) -> D
) -> Func<C, D> {
    .init(f(a.call))
}

public func |> <A, B, C, D> (
    a: Func<A, B>,
    f: (Func<A, B>) -> Func<C, D>
) -> Func<C, D> {
    f(a)
}

public func |> <A, B, C, D, E: CallableAsFunction> (
    a: Func<A, B>,
    f: E
) -> Func<C, D> where E.A == (A) -> B, E.B == (C) -> D {
    Func<C, D>.init(f(a.call))
}

/*:
 Allow structs which are callable as functions
 of one value to get all the same operations
 as regular functions
 */
public protocol CallableAsFunction {
    associatedtype A
    associatedtype B
    var call: (A) -> B { get }
    
    init(_ call: @escaping (A) -> B)
    init(_ f: Func<A, B>)
    init<C: CallableAsFunction>(_ c: C) where C.A == A, C.B == B
    
    func callAsFunction(_ a: A) -> B
}

public extension CallableAsFunction {
    var callable: Func<A, B> { .init(call) }
    func callAsFunction(_ a: A) -> B { call(a) }
}
   
// Map
public extension CallableAsFunction {
    // f >>> self = ((A) -> B) >>> ((B) -> C) = (A) -> C
    func map<C>(
        _ f: @escaping (B) -> C
    ) -> Func<A, C> {
        self >>> f
    }

    func map<C>(
        _ f: Func<B, C>
    ) -> Func<A, C> {
        self >>> f
    }

    func map<C: CallableAsFunction>(
        _ f: C
    ) -> Func<A, C.B> where B == C.A {
        self >>> f
    }
}

// ContraMap
public extension CallableAsFunction {
    // f >>> self = ((C) -> A) >>> ((A) -> B)
    //            =  (C) -> B
    func contraMap<C>(
        _ f: @escaping (C) -> A
    ) -> Func<C, B> {
        f >>> self
    }

    func contraMap<C>(
        _ f: Func<C, A>
    ) -> Func<C, B> {
        f >>> self
    }
    
    func contraMap<C: CallableAsFunction>(
        _ f: C
    ) -> Func<C.A, B> where C.B == A{
        f >>> self
    }
}
 
// FlatMap
public extension CallableAsFunction {
    //        self >>> f = ((A) ->  B) >>> (B) -> (A) -> C
    //                   =  (A) -> (A) -> C
    //
    // a |> (self >>> f) =  (A) ->  C
    func flatMap<C>(
        _ f: @escaping (B) -> (A) -> C
    ) -> Func<A, C> {
        .init { (a: A) in  a |> a |> self >>> f }
    }

    func flatMap<C>(
        _ f: Func<B, Func<A, C>>
    ) -> Func<A, C> {
        .init { (a: A) in  a |> a |> self >>> f }
    }

    func flatMap<C, D: CallableAsFunction>(
        _ f: D
    ) -> Func<A, C> where D.A == B, D.B == Func<A, C> {
        .init { (a: A) in  a |> a |> self >>> f }
    }
}

// ContraFlatMap
public extension CallableAsFunction {
    // self |> join = (A -> B) |> ((A) -> B) -> (A) -> B)
    //              = A -> B
    // transform >>> (self |> join) = (C -> A) >>> (A -> B)
    //                              =  C -> B
    func contraFlatMap<C>(
        _ join:  @escaping ((A) -> B) -> (A) -> B,
        _ transform:@escaping (C) -> A
    ) -> Func<C, B> {
        transform >>> self |> join
    }
    
    func contraFlatMap<C>(
        _ join:  @escaping ((A) -> B) -> (A) -> B,
        _ transform: Func<C, A>
    ) -> Func<C, B> {
        transform >>> self |> join
    }
    
    func contraFlatMap<D: CallableAsFunction>(
        _ join:  @escaping ((A) -> B) -> (A) -> B,
        _ transform: D
    ) -> Func<D.A, B> where D.B == Self.A {
        transform >>> self |> join
    }
    
    func contraFlatMap<C>(
        _ join:  Func<Self, Self>,
        _ transform: @escaping (C) -> A
    ) -> Func<C, B> {
        transform >>> self |> join
    }
    
    func contraFlatMap<C>(
        _ join:  Func<Self, Self>,
        _ transform: Func<C, A>
    ) -> Func<C, B> {
        transform >>> self |> join
    }

    func contraFlatMap<C, D: CallableAsFunction>(
        _ join:  Func<Self, Self>,
        _ transform: D
    ) -> Func<C, B> where D.A == C, D.B == Self.A {
        transform >>> self |> join
    }

    func contraFlatMap<C>(
        _ join:  @escaping (Self) -> Self,
        _ transform: @escaping (C) -> A
    ) -> Func<C, B> {
        transform >>> self |> join
    }
    
    func contraFlatMap<C>(
        _ join:  @escaping (Self) -> Self,
        _ transform: Func<C, A>
    ) -> Func<C, B> {
        transform >>> self |> join
    }

    func contraFlatMap<C, D: CallableAsFunction>(
        _ join:  @escaping (Self) -> Self,
        _ transform: D
    ) -> Func<C, B> where D.A == C, D.B == Self.A {
        transform >>> self |> join
    }
}

// DiMap
public extension CallableAsFunction {
    // C -> A >>> A -> B >>> B -> D = C -> B >>> B -> D
    //                              = C -> D
    func dimap<C, D>(
        _ hoist: @escaping (C) -> A,
        _ lower: @escaping (B) -> D
    ) -> Func<C, D> {
        hoist >>> self >>> lower
    }

    func dimap<C, D>(
        _ hoist: @escaping (C) -> A,
        _ lower: Func<B, D>
    ) -> Func<C, D> {
        hoist >>> self >>> lower
    }

    func dimap<C, D: CallableAsFunction>(
        _ hoist: @escaping (C) -> A,
        _ lower: D
    ) -> Func<C, D.B> where D.A == B {
        hoist >>> self >>> lower
    }

    func dimap<C, D>(
        _ hoist: Func<C, A>,
        _ lower: @escaping (B) -> D
    ) -> Func<C, D> {
        hoist >>> self >>> lower
    }

    func dimap<C, D>(
        _ hoist: Func<C, A>,
        _ lower: Func<B, D>
    ) -> Func<C, D> {
        hoist >>> self >>> lower
    }

    func dimap<C, D: CallableAsFunction>(
        _ hoist: Func<C, A>,
        _ lower: D
    ) -> Func<C, D.B> where D.A == B {
        hoist >>> self >>> lower
    }

    func dimap<C: CallableAsFunction, D>(
        _ hoist: C,
        _ lower: @escaping (B) -> D
    ) -> Func<C.A, D> where C.B == A
    {
        hoist >>> self >>> lower
    }

    func dimap<C: CallableAsFunction, D>(
        _ hoist: C,
        _ lower: Func<B, D>
    ) -> Func<C.A, D> where C.B == A
    {
        hoist >>> self >>> lower
    }

    func dimap<C: CallableAsFunction, D: CallableAsFunction>(
        _ hoist: C,
        _ lower: D
    ) -> Func<C.A, D.B> where D.A == B, C.B == A {
        hoist >>> self >>> lower
    }
}

/*:
 Define a struct which wraps a function
 underneath and meets the above protocol.
 */
public struct Func<FA, FB>: CallableAsFunction {
    public typealias A = FA
    public typealias B = FB
    public let call: (FA) -> FB
    
    public init(_ call: @escaping (FA) -> FB) {
        self.call = call
    }
    
    public init(_ f: Func<A, B>) {
        self.call = f.call
    }
    
    public init<C>(_ c: C) where C : CallableAsFunction, Self.A == C.A, Self.B == C.B {
        self.call = c.call
    }
    
    public init<C>(_ f: @escaping (A) throws -> C) where B == Result<C, Error> {
        self = .init {
            do { return .success(try f($0)) }
            catch { return .failure(error) }
        }
    }
}
