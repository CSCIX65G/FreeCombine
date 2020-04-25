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

infix operator >>>: CompositionPrecedence

func >>> <A, B, C>(
    _ f: @escaping (A) -> B,
    _ g: @escaping (B) -> C
) -> (A) -> C {
    { (a: A) -> C in g(f(a)) }
}

infix operator |>: CompositionPrecedence
public func |> <A, B> (a: A, f: (A) -> B) -> B { f(a) }

public func identity<T>(_ t: T) -> T { t }
public func void<T>(_ t: T) -> Void { }

public func curry<A, B, C>(
    _ function: @escaping (A, B) -> C
) -> (A) -> (B) -> C {
    { (a: A) -> (B) -> C in
        { (b: B) -> C in
            function(a, b)
        }
    }
}

public protocol CallableAsFunction {
    associatedtype A
    associatedtype B
    var call: (A) -> B { get }
    
    init(_ call: @escaping (A) -> B)
    
    init(_ f: Func<A, B>)
    
    static func pure<T, U>(_ t: T) -> Self where A == U, B == T
    
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
    
    func flatMap<C>(
        join:  @escaping (Self) -> Self,
        transform:  @escaping (B) -> C
    ) -> Func<A, C>
    
    func contraFlatMap<C>(
        _ f:  @escaping (C) -> (C) -> A
    ) -> Func<C, B>
    
    func contraFlatMap<C>(
        _ join:  @escaping (Self) -> Self,
        _ transform:  @escaping (C) -> A
    ) -> Func<C, B>
    
    func dimap<C, D>(
        _ f:  @escaping (C) -> A,
        _ g:  @escaping (B) -> D
    ) -> Func<C, D>
}

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
}

public extension CallableAsFunction {
    static func pure<T, U>(_ t: T) -> Self where A == U, B == T {
        return .init { _ in t }
    }

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
    
    //bind form
    func flatMap<C>(
        _ f: @escaping (B) -> (A) -> C
    ) -> Func<A, C> {
        .init { (self >>> f)($0)($0) }
    }

    // join form
    func flatMap<C>(
        join: (Self) -> Self,
        transform: @escaping (B) -> C
    ) -> Func<A, C> {
        join(self) >>> transform
    }

    // bind form
    func contraFlatMap<C>(
        _ f:  @escaping (C) -> (C) -> A
    ) -> Func<C, B> {
        .init { (f($0) >>> self)($0) }
    }

    // join form
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
