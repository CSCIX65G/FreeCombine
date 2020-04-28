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
 Define composition of two functions
 */
infix operator >>>: CompositionPrecedence
public func >>> <A, B, C>(
    _ f: @escaping (A) -> B,
    _ g: @escaping (B) -> C
) -> (A) -> C {
    { (a: A) -> C in g(f(a)) }
}

/*:
 Define application of a function to a
 value
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
        self >>> f
    }

    func contraMap<C>(
        _ f: @escaping (C) -> A
    ) -> Func<C, B> {
        f >>> self
    }
    
    func flatMap<C>(
        _ f: @escaping (B) -> (A) -> C
    ) -> Func<A, C> {
        .init { (self >>> f)($0)($0) }
    }

    func contraFlatMap<C>(
        _ join:  @escaping (Self) -> Self,
        _ transform:@escaping (C) -> A
    ) -> Func<C, B> {
        transform >>> join(self)
    }
    
    func dimap<C, D>(
        _ f: @escaping (C) -> A,
        _ g: @escaping (B) -> D
    ) -> Func<C, D> {
        f >>> self >>> g
    }
}

/*:
 Define a struct which wraps a function
 underneath to serve as the value returned
 from the functions above.
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
