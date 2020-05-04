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
 Sometimes we need a reference to a value type (sadly)
 We want it to be generic and to return the value
 when set so that it can be composed
 */
public final class Reference<Value> {
    var value: Value
    init(_ state: Value) {
        self.value = state
    }
    
    func set(_ state: Value) -> Value {
        self.value = state
        return state
    }
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
    
    func callAsFunction(_ a: A) -> B
    
    func map<C>(
        _ f: @escaping (B) -> C
    ) -> Func<A, C>
    
    func contraMap<C>(
        _ f:  @escaping (C) -> A
    ) -> Func<C, B>
    
    func flatMap<C>(
        _ f:  @escaping (B) -> (A) -> C
    ) -> Func<A, C>
    
    func contraFlatMap<C>(
        _ join:  @escaping (Self) -> Self,
        _ transform:  @escaping (C) -> A
    ) -> Func<C, B>
    
    func dimap<C, D>(
        _ f:  @escaping (C) -> A,
        _ g:  @escaping (B) -> D
    ) -> Func<C, D>
}

public extension CallableAsFunction {
    func callAsFunction(_ a: A) -> B {
        call(a)
    }
        
    func map<C>(
        _ f: @escaping (B) -> C
    ) -> Func<A, C> {
        // (A -> B) >>> (B -> C) = (A -> C)
        self >>> f
    }

    func contraMap<C>(
        _ f: @escaping (C) -> A
    ) -> Func<C, B> {
        // (C -> A) >>> (A -> B) = (C -> B)
        f >>> self
    }
    
    func flatMap<C>(
        _ f: @escaping (B) -> (A) -> C
    ) -> Func<A, C> {
        // self >>> f = ((A) -> B) >>> (B) -> (A) -> C = (A) -> (A) -> C
        // a |> (self >>> f) = (A) -> C
        .init { (a: A) in  a |> (a |> (self >>> f)) }
    }

    // The key point is that (Self) -> Self
    // allows us to substitute in any function
    // at all for self as long as it accepts and
    // returns the same values.  In particular we can
    // substitute in a function will will call self
    // repeatedly
    func contraFlatMap<C>(
        _ join:  @escaping (Self) -> Self,
        _ transform:@escaping (C) -> A
    ) -> Func<C, B> {
        // self |> join = (A -> B) |> ((A) -> B) -> (A) -> B) = A -> B
        // transform >>> (self |> join)
        // = (C -> A) >>> (A -> B) = C -> B
        transform >>> (self |> join)
    }
    
    func dimap<C, D>(
        _ hoist: @escaping (C) -> A,
        _ lower: @escaping (B) -> D
    ) -> Func<C, D> {
        // C -> A >>> A -> B >>> B -> D = C -> D
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
