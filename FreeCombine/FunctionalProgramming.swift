//
//  FunctionProgramming.swift
//  FreeCombine
//
//  Created by Van Simmons on 4/11/20.
//  Copyright © 2020 ComputeCycles, LLC. All rights reserved.
//

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
) -> (A) -> C {
    { (a: A) -> C in g(f(a)) }
}

/*:
 Define an operator for the application of a
 function to a value
 */
infix operator |>: CompositionPrecedence
public func |> <A, B> (
    a: A,
    f: (A) -> B
) -> B { f(a) }

/*:
 Handy functions for composition
 */
public func identity<T>(_ t: T) -> T { t }
public func void<T>(_ t: T) -> Void { }
public func cons<T>(_ t: T) -> () -> T { { t } }
public func unwrap<T>(_ t: T?) -> T { t! }

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
    func callAsFunction(_ a: A) -> B
}

public extension CallableAsFunction {
    var function: Func<A, B> { .init(call) }
    
    func callAsFunction(_ a: A) -> B {
        call(a)
    }
}
   
// Map
public extension CallableAsFunction {
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
}

// ContraMap
public extension CallableAsFunction {
    func contraMap<C>(
        _ f: Func<C, A>
    ) -> Func<C, B> {
        f >>> self
    }
    
    func contraMap<C>(
        _ f: @escaping (C) -> A
    ) -> Func<C, B> {
        f >>> self
    }
}
 
// FlatMap
public extension CallableAsFunction {
    // self >>> f = ((A) -> B) >>> (B) -> (A) -> C = (A) -> (A) -> C
    // a |> (self >>> f) = (A) -> C
    func flatMap<C>(
        _ f: @escaping (B) -> (A) -> C
    ) -> Func<A, C> {
        .init { (a: A) in  a |> (a |> (self >>> f)) }
    }

    func flatMap<C>(
        _ f: Func<B, Func<A, C>>
    ) -> Func<A, C> {
        .init { (a: A) in  a |> (a |> (self >>> f)) }
    }
}

// ContraFlatMap
public extension CallableAsFunction {
    // self |> join = (A -> B) |> ((A) -> B) -> (A) -> B) = A -> B
    // transform >>> (self |> join) = (C -> A) >>> (A -> B) = C -> B
    func contraFlatMap<C>(
        _ join:  @escaping ((A) -> B) -> (A) -> B,
        _ transform:@escaping (C) -> A
    ) -> Func<C, B> {
        transform >>> Func(self |> join)
    }
    
    func contraFlatMap<C>(
        _ join:  @escaping (Self) -> Self,
        _ transform:@escaping (C) -> A
    ) -> Func<C, B> {
        transform >>> (self |> join)
    }
    
    func contraFlatMap<C>(
        _ join:  @escaping ((A) -> B) -> (A) -> B,
        _ transform: Func<C, A>
    ) -> Func<C, B> {
        transform >>> Func(self |> join)
    }
    
    func contraFlatMap<C>(
        _ join:  Func<Self, Self>,
        _ transform: Func<C, A>
    ) -> Func<C, B> {
        transform >>> (self |> join)
    }
}

// DiMap
public extension CallableAsFunction {
    // C -> A >>> A -> B >>> B -> D = C -> D
    func dimap<C, D>(
        _ hoist: @escaping (C) -> A,
        _ lower: @escaping (B) -> D
    ) -> Func<C, D> {
        hoist >>> self >>> lower
    }

    func dimap<C, D>(
        _ hoist: Func<C, A>,
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

    func dimap<C, D>(
        _ hoist: Func<C, A>,
        _ lower: Func<B, D>
    ) -> Func<C, D> {
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
    
    public init<C>(_ f: @escaping (A) throws -> C) where B == Result<C, Error> {
        self = .init {
            do { return .success(try f($0)) }
            catch { return .failure(error) }
        }
    }
}

/*:
 Various forms of mixing plain functions with Funcs
 */
func >>> <A, B, C, D: CallableAsFunction> (
    _ f: @escaping (A) -> B,
    _ g: D
) -> Func<A,C> where D.A == B, D.B == C {
    .init(f >>> g.call)
}

func >>> <A, B, C, D: CallableAsFunction>(
    _ f: D,
    _ g: @escaping (B) -> C
) -> Func<A,C> where D.A == A, D.B == B {
    .init(f.call >>> g)
}

func >>> <A, B, C, D: CallableAsFunction, E: CallableAsFunction> (
    _ f: D,
    _ g: E
) -> Func<A,C> where D.A == A, D.B == B, E.A == B, E.B == C{
    .init(f.call >>> g.call)
}

public func |> <A, B, C: CallableAsFunction> (a: A, f: C) -> B
    where A == C.A, B == C.B {
    f(a)
}

public func |> <A, B: CallableAsFunction, C: CallableAsFunction> (a: A, f: C) -> B
    where A == C.A, B == C.B {
    f(a)
}

public func |> <A: CallableAsFunction, B: CallableAsFunction, C: CallableAsFunction> (a: A, f: C) -> B
    where A == C.A, B == C.B {
    f(a)
}

public func |> <A: CallableAsFunction, B, C: CallableAsFunction> (a: A, f: C) -> B
    where A == C.A, B == C.B {
    f(a)
}

public func |> <A: CallableAsFunction, B: CallableAsFunction> (
    a: A,
    f: ((A.A) -> A.B) -> (B.A) -> B.B
) -> B {
    .init(f(a.call))
}

public func |> <A, B: CallableAsFunction> (
    a: @escaping (A) -> B,
    f: @escaping ((A) -> B) -> (B.A) -> B.B
) -> B {
    .init(f(a))
}
